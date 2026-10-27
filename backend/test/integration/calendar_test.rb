require "test_helper"

class CalendarTest < ActionDispatch::IntegrationTest
  setup do
    https!
    @owner = create_user("owner@coloc.test")
    sign_in(@owner)
    @coloc = create_coloc
  end

  test "creates a timed event and expands weekly all-day tuesdays" do
    post api_coloc_events_path(@coloc), params: {
      title: "Réunion",
      all_day: false,
      starts_at: "2026-10-23T18:00",
      ends_at: "2026-10-23T19:30",
      recurrence: "none"
    }, as: :json
    assert_response :created

    post api_coloc_events_path(@coloc), params: {
      title: " Poubelles ",
      all_day: true,
      starts_at: "2026-10-06",
      ends_at: "2026-10-06",
      recurrence: "weekly",
      weekdays: [ 2 ]
    }, as: :json
    assert_response :created
    created = JSON.parse(response.body).fetch("event")
    assert_equal "Poubelles", created.fetch("title")
    assert_equal "2026-10-06T00:00:00+02:00", created.fetch("starts_at")
    assert_equal "2026-10-07T00:00:00+02:00", created.fetch("ends_at")
    assert_equal [ 2 ], created.fetch("weekdays")

    get api_coloc_calendar_path(@coloc, from: "2026-10-01", to: "2026-10-31"), as: :json
    assert_response :success
    events = JSON.parse(response.body).fetch("events")
    tuesdays = events.select { |event| event.fetch("title") == "Poubelles" }
    assert_equal [ "2026-10-06", "2026-10-13", "2026-10-20", "2026-10-27" ], tuesdays.map { |event| event.fetch("occurrence_on") }
    assert tuesdays.all? { |event| event.fetch("recurring") }

    meeting = events.find { |event| event.fetch("title") == "Réunion" }
    assert_equal false, meeting.fetch("all_day")
    assert_includes meeting.fetch("starts_at"), "T18:00:00+02:00"
    assert_includes meeting.fetch("ends_at"), "T19:30:00+02:00"
  end

  test "cancels one occurrence, overrides another, then deletes the series" do
    event_id = create_trash

    delete api_coloc_event_path(@coloc, event_id, occurrence: "2026-10-13"), as: :json
    assert_response :no_content
    assert_equal [ "2026-10-06", "2026-10-20", "2026-10-27" ], trash_dates

    patch api_coloc_event_path(@coloc, event_id, occurrence: "2026-10-20"), params: {
      title: "Poubelles spéciales",
      all_day: true,
      starts_at: "2026-10-20",
      ends_at: "2026-10-20",
      recurrence: "weekly",
      weekdays: [ 2 ]
    }, as: :json
    assert_response :success
    titles = calendar_events.select { |event| event.fetch("recurrence") == "weekly" }.to_h { |event| [ event.fetch("occurrence_on"), event.fetch("title") ] }
    assert_equal "Poubelles", titles.fetch("2026-10-06")
    assert_equal "Poubelles spéciales", titles.fetch("2026-10-20")
    assert_nil titles["2026-10-13"]

    delete api_coloc_event_path(@coloc, event_id), as: :json
    assert_response :no_content
    assert_empty trash_dates
  end

  test "cycles a rotation with an offset and without an end date" do
    travel_to Time.zone.local(2026, 10, 23, 12, 0, 0) do
      bea = create_user("bea@coloc.test", first_name: "Bea")
      noam = create_user("noam@coloc.test", first_name: "Noam")
      @coloc.add_member(bea)
      @coloc.add_member(noam)

      post api_coloc_rotations_path(@coloc), params: {
        title: "Ménage",
        starts_on: "2026-10-20",
        turn_days: 7,
        offset_days: 1,
        member_ids: [ @owner.id, bea.id, noam.id ]
      }, as: :json
      assert_response :created
      rotation = JSON.parse(response.body).fetch("rotation")
      assert_equal "2026-10-20", rotation.fetch("starts_on")
      assert_nil rotation.fetch("ends_on")
      assert_equal 1, rotation.fetch("offset_days")
      assert_equal [
        [ "2026-10-20", "2026-10-26", "Ada" ],
        [ "2026-10-28", "2026-11-03", "Bea" ],
        [ "2026-11-05", "2026-11-11", "Noam" ],
        [ "2026-11-13", "2026-11-19", "Ada" ]
      ], duty_rows

      patch api_coloc_rotation_path(@coloc, rotation.fetch("id")), params: {
        title: "Ménage",
        starts_on: "2026-10-20",
        turn_days: 7,
        offset_days: 1,
        member_ids: [ @owner.id, noam.id ]
      }, as: :json
      assert_response :success
      assert_equal "2026-10-20", JSON.parse(response.body).dig("rotation", "starts_on")
      assert_nil JSON.parse(response.body).dig("rotation", "ends_on")
      assert_equal [
        [ "2026-10-20", "2026-10-26", "Ada" ],
        [ "2026-10-28", "2026-11-03", "Noam" ],
        [ "2026-11-05", "2026-11-11", "Ada" ],
        [ "2026-11-13", "2026-11-19", "Noam" ]
      ], duty_rows
    end
  end

  test "leaving the coloc removes that person from rotations" do
    travel_to Time.zone.local(2026, 10, 23, 12, 0, 0) do
      bea = create_user("bea@coloc.test", first_name: "Bea")
      @coloc.add_member(bea)
      post api_coloc_rotations_path(@coloc), params: {
        title: "Ménage",
        starts_on: "2026-10-05",
        turn_days: 7,
        offset_days: 0,
        member_ids: [ @owner.id, bea.id ]
      }, as: :json
      assert_response :created

      sign_in(bea)
      delete api_coloc_membership_path(@coloc), as: :json
      assert_response :no_content

      sign_in(@owner)
      duties = duty_rows
      assert_equal [ "Ada" ], duties.map(&:last).uniq
      assert_equal "2026-10-05", JSON.parse(response.body).fetch("rotations").first.fetch("rule_starts_on")
    end
  end

  test "refuses the calendar to someone who is not a member" do
    sign_in(create_user("guest@coloc.test"))

    get api_coloc_calendar_path(@coloc, from: "2026-10-01", to: "2026-10-31"), as: :json
    assert_response :forbidden

    post api_coloc_events_path(@coloc), params: {
      title: "Intrusion",
      all_day: true,
      starts_at: "2026-10-06",
      ends_at: "2026-10-06"
    }, as: :json
    assert_response :forbidden

    post api_coloc_rotations_path(@coloc), params: {
      title: "Intrusion",
      starts_on: "2026-10-20",
      turn_days: 7,
      offset_days: 0,
      member_ids: [ @owner.id ]
    }, as: :json
    assert_response :forbidden
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

    def create_trash
      post api_coloc_events_path(@coloc), params: {
        title: "Poubelles",
        all_day: true,
        starts_at: "2026-10-06",
        ends_at: "2026-10-06",
        recurrence: "weekly",
        weekdays: [ 2 ]
      }, as: :json
      assert_response :created
      JSON.parse(response.body).dig("event", "id")
    end

    def calendar_events
      get api_coloc_calendar_path(@coloc, from: "2026-10-01", to: "2026-10-31"), as: :json
      assert_response :success
      JSON.parse(response.body).fetch("events")
    end

    def trash_dates
      calendar_events.select { |event| event.fetch("title").start_with?("Poubelles") }.map { |event| event.fetch("occurrence_on") }
    end

    def duty_rows
      get api_coloc_calendar_path(@coloc, from: "2026-10-19", to: "2026-11-15"), as: :json
      assert_response :success
      JSON.parse(response.body).fetch("rotations").map do |slot|
        [ slot.fetch("starts_on"), slot.fetch("ends_on"), slot.dig("user", "first_name") ]
      end
    end
end
