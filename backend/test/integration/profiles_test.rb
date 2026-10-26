require "test_helper"

class ProfilesTest < ActionDispatch::IntegrationTest
  setup do
    https!
    @owner = create_user("owner@coloc.test")
    sign_in(@owner)
    @coloc = create_coloc
  end

  test "shows the current member profile" do
    get api_coloc_profile_path(@coloc, @owner), as: :json

    assert_response :success
    profile = JSON.parse(response.body).fetch("profile")
    assert_equal @owner.id, profile.fetch("id")
    assert_equal "Ada", profile.fetch("first_name")
    assert_equal "Lovelace", profile.fetch("last_name")
    assert_nil profile.fetch("description")
    assert_nil profile.fetch("mood")
    assert_nil profile.fetch("pronouns")
    assert_equal "1990-01-01", profile.fetch("date_of_birth")
    assert_equal Date.current.to_s, profile.fetch("arrived_on")
    assert_nil profile.fetch("avatar_url")
    assert_not profile.key?("email")
  end

  test "shows another member of the coloc" do
    guest = create_user("guest@coloc.test", first_name: "Grace")
    @coloc.add_member(guest)

    get api_coloc_profile_path(@coloc, guest), as: :json

    assert_response :success
    assert_equal "Grace", JSON.parse(response.body).dig("profile", "first_name")
    assert_equal Date.current.to_s, JSON.parse(response.body).dig("profile", "arrived_on")
  end

  test "hides a profile from someone outside the coloc" do
    sign_in(create_user("outsider@coloc.test"))

    get api_coloc_profile_path(@coloc, @owner), as: :json

    assert_response :forbidden
  end

  test "returns not found when the user is not in the coloc" do
    stranger = create_user("stranger@coloc.test")

    get api_coloc_profile_path(@coloc, stranger), as: :json

    assert_response :not_found
  end

  test "updates the current profile including photo and arrival date" do
    patch api_coloc_profile_path(@coloc, @owner), params: profile_fields, as: :json

    assert_response :success
    profile = JSON.parse(response.body).fetch("profile")
    assert_equal "Augusta", profile.fetch("first_name")
    assert_equal "King", profile.fetch("last_name")
    assert_equal "J'aime le silence", profile.fetch("description")
    assert_equal "Au calme", profile.fetch("mood")
    assert_equal "elle", profile.fetch("pronouns")
    assert_equal "1815-12-10", profile.fetch("date_of_birth")
    assert_equal "2020-05-01", profile.fetch("arrived_on")

    patch api_coloc_profile_path(@coloc, @owner),
      params: profile_fields(avatar: png_file),
      headers: requested_with
    assert_response :success
    assert_includes JSON.parse(response.body).dig("profile", "avatar_url"), "/rails/active_storage/representations/"

    patch api_coloc_profile_path(@coloc, @owner), params: profile_fields(remove_avatar: true), as: :json
    assert_response :success
    assert_nil JSON.parse(response.body).dig("profile", "avatar_url")
    assert_not @owner.reload.avatar.attached?
  end

  test "refuses to update another member" do
    guest = create_user("guest@coloc.test")
    @coloc.add_member(guest)

    patch api_coloc_profile_path(@coloc, guest), params: profile_fields(first_name: "Pirate"), as: :json

    assert_response :forbidden
    assert_equal "Ada", guest.reload.first_name
  end

  test "rejects an arrival date in the future" do
    patch api_coloc_profile_path(@coloc, @owner),
      params: profile_fields(arrived_on: Date.tomorrow.to_s),
      as: :json

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body).fetch("errors").join, "arrivée"
    assert_equal Date.current, @coloc.memberships.find_by!(user: @owner).reload.arrived_on
  end

  test "rejects an avatar that is not an image" do
    patch api_coloc_profile_path(@coloc, @owner),
      params: profile_fields(avatar: text_file),
      headers: requested_with

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body).fetch("errors").join, "photo"
    assert_not @owner.reload.avatar.attached?
  end

  private
    def create_user(email, first_name: "Ada")
      User.create!(
        email: email,
        password: "secretpass",
        password_confirmation: "secretpass",
        first_name: first_name,
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

    def profile_fields(avatar: nil, remove_avatar: false, arrived_on: "2020-05-01", first_name: "Augusta")
      fields = {
        first_name: first_name,
        last_name: "King",
        description: " J'aime le silence ",
        mood: " Au calme ",
        pronouns: "elle",
        date_of_birth: "1815-12-10",
        arrived_on: arrived_on
      }
      fields[:avatar] = avatar if avatar
      fields[:remove_avatar] = true if remove_avatar
      fields
    end

    def requested_with
      { "X-Requested-With" => "XMLHttpRequest" }
    end

    def png_file
      path = Rails.root.join("tmp/pixel.png")
      File.binwrite(path, Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="))
      Rack::Test::UploadedFile.new(path, "image/png", true)
    end

    def text_file
      path = Rails.root.join("tmp/note.txt")
      File.write(path, "bonjour")
      Rack::Test::UploadedFile.new(path, "text/plain", false, original_filename: "note.txt")
    end
end
