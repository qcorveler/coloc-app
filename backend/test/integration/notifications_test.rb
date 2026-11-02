require "test_helper"

class NotificationsTest < ActionDispatch::IntegrationTest
  setup do
    https!
    @owner = create_user("owner@coloc.test")
    sign_in(@owner)
    @coloc = create_coloc
  end

  test "push subscription requires a session" do
    delete api_session_path, as: :json
    assert_response :no_content

    get api_push_subscription_path, as: :json
    assert_response :unauthorized

    put api_push_subscription_path, params: push_params("https://push.example.test/ada"), as: :json
    assert_response :unauthorized
  end

  test "registers, reassigns and removes a device" do
    put api_push_subscription_path, params: push_params("https://push.example.test/ada"), as: :json
    assert_response :no_content

    get api_push_subscription_path(endpoint: "https://push.example.test/ada"), as: :json
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal true, body.fetch("subscribed")
    assert_equal "test-public-key", body.fetch("public_key")

    bea = create_user("bea@coloc.test", first_name: "Bea")
    sign_in(bea)
    put api_push_subscription_path, params: push_params("https://push.example.test/ada"), as: :json
    assert_response :no_content
    assert_equal bea, PushSubscription.find_by!(endpoint: "https://push.example.test/ada").user
    assert_empty @owner.push_subscriptions

    delete api_push_subscription_path, params: { endpoint: "https://push.example.test/ada" }, as: :json
    assert_response :no_content
    assert_nil PushSubscription.find_by(endpoint: "https://push.example.test/ada")
  end

  test "refuses an incomplete push subscription" do
    put api_push_subscription_path, params: { endpoint: "https://push.example.test/ada" }, as: :json
    assert_response :unprocessable_entity
  end

  test "reminds selected people and subscribers, skips a cancelled day, and does not send twice" do
    bea = create_user("bea@coloc.test", first_name: "Bea")
    @coloc.add_member(bea)
    event_id = create_trash(remind_user_ids: [ @owner.id ])
    sign_in(bea)
    post api_coloc_event_reminder_path(@coloc, event_id), params: {}, as: :json
    assert_response :no_content
    subscribe(@owner, "https://push.example.test/ada")
    subscribe(bea, "https://push.example.test/bea")

    sent = capture_pushes do
      travel_to Time.zone.local(2026, 10, 5, 19, 0, 0) do
        CalendarRemindersJob.perform_now
        CalendarRemindersJob.perform_now
      end
    end
    assert_equal [ "Demain : Poubelles", "Demain : Poubelles" ].sort, sent.map { |payload| JSON.parse(payload.fetch(:message)).fetch("title") }.sort
    assert sent.all? { |payload| JSON.parse(payload.fetch(:message)).fetch("body") == "Les Lilas" }
    assert sent.all? { |payload| JSON.parse(payload.fetch(:message)).fetch("path") == "/colocs/#{@coloc.id}/planning" }
    assert_equal [ @owner.id, bea.id ].sort, sent.map { |payload| PushSubscription.find_by!(endpoint: payload.fetch(:endpoint)).user_id }.sort

    sign_in(@owner)
    delete api_coloc_event_path(@coloc, event_id, occurrence: "2026-10-13"), as: :json
    assert_response :no_content
    sent = capture_pushes do
      travel_to Time.zone.local(2026, 10, 12, 19, 0, 0) do
        CalendarRemindersJob.perform_now
      end
    end
    assert_empty sent
  end

  test "uses the title of a modified occurrence" do
    event_id = create_trash(remind_user_ids: [ @owner.id ])
    subscribe(@owner, "https://push.example.test/ada")
    patch api_coloc_event_path(@coloc, event_id, occurrence: "2026-10-20"), params: {
      title: "Poubelles spéciales",
      all_day: true,
      starts_at: "2026-10-20",
      ends_at: "2026-10-20",
      recurrence: "weekly",
      weekdays: [ 2 ]
    }, as: :json
    assert_response :success

    sent = capture_pushes do
      travel_to Time.zone.local(2026, 10, 19, 19, 0, 0) do
        CalendarRemindersJob.perform_now
      end
    end
    assert_equal [ "Demain : Poubelles spéciales" ], sent.map { |payload| JSON.parse(payload.fetch(:message)).fetch("title") }
  end

  test "notifies the person whose turn starts tomorrow and not the following days" do
    bea = create_user("bea@coloc.test", first_name: "Bea")
    @coloc.add_member(bea)
    post api_coloc_rotations_path(@coloc), params: {
      title: "Ménage",
      starts_on: "2026-10-06",
      turn_days: 7,
      offset_days: 0,
      member_ids: [ @owner.id, bea.id ]
    }, as: :json
    assert_response :created
    subscribe(@owner, "https://push.example.test/ada")
    subscribe(bea, "https://push.example.test/bea")

    sent = capture_pushes do
      travel_to Time.zone.local(2026, 10, 5, 19, 0, 0) do
        CalendarRemindersJob.perform_now
      end
    end
    assert_equal [ "https://push.example.test/ada" ], sent.map { |payload| payload.fetch(:endpoint) }
    assert_equal "Ton tour commence : Ménage", JSON.parse(sent.first.fetch(:message)).fetch("title")

    sent = capture_pushes do
      travel_to Time.zone.local(2026, 10, 6, 19, 0, 0) do
        CalendarRemindersJob.perform_now
      end
    end
    assert_empty sent

    sent = capture_pushes do
      travel_to Time.zone.local(2026, 10, 12, 19, 0, 0) do
        CalendarRemindersJob.perform_now
      end
    end
    assert_equal [ "https://push.example.test/bea" ], sent.map { |payload| payload.fetch(:endpoint) }
  end

  test "leaving the coloc drops that person's event reminders" do
    bea = create_user("bea@coloc.test", first_name: "Bea")
    @coloc.add_member(bea)
    create_trash(remind_user_ids: [ bea.id ])

    sign_in(bea)
    delete api_coloc_membership_path(@coloc), as: :json
    assert_response :no_content
    assert_empty EventReminder.where(user: bea)
  end

  test "refuses a reminder list that includes someone outside the coloc" do
    guest = create_user("guest@coloc.test")
    post api_coloc_events_path(@coloc), params: trash_params(remind_user_ids: [ guest.id ]), as: :json
    assert_response :unprocessable_entity
    assert_empty @coloc.events
  end

  private
    def create_user(email, first_name: "Ada")
      User.create!(
        email:,
        password: "secretpass",
        password_confirmation: "secretpass",
        first_name:,
        last_name: "Lovelace",
        date_of_birth: "1990-01-01"
      )
    end

    def sign_in(user)
      post api_session_path, params: { email: user.email, password: "secretpass" }, as: :json
      assert_response :success
    end

    def create_coloc
      post api_colocs_path, params: { name: "Les Lilas", address: "1 rue des Lilas" }, as: :json
      assert_response :created
      Coloc.find(JSON.parse(response.body).dig("coloc", "id"))
    end

    def trash_params(remind_user_ids:)
      {
        title: "Poubelles",
        all_day: true,
        starts_at: "2026-10-06",
        ends_at: "2026-10-06",
        recurrence: "weekly",
        weekdays: [ 2 ],
        remind_user_ids:
      }
    end

    def create_trash(remind_user_ids:)
      post api_coloc_events_path(@coloc), params: trash_params(remind_user_ids:), as: :json
      assert_response :created
      JSON.parse(response.body).dig("event", "id")
    end

    def push_params(endpoint)
      { endpoint:, p256dh: "key", auth: "secret" }
    end

    def subscribe(user, endpoint)
      user.push_subscriptions.create!(endpoint:, p256dh: "key", auth: "secret")
    end

    def capture_pushes
      sent = []
      eigenclass = class << WebPush; self; end
      original = eigenclass.instance_method(:payload_send)
      eigenclass.define_method(:payload_send) { |**payload| sent << payload }
      yield
      sent
    ensure
      eigenclass.define_method(:payload_send, original) if eigenclass && original
    end
end
