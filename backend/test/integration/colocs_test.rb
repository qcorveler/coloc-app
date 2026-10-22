require "test_helper"

class ColocsTest < ActionDispatch::IntegrationTest
  setup do
    https!
    @owner = create_user("owner@coloc.test")
    sign_in(@owner)
  end

  test "creates a coloc without a photo" do
    assert_difference [ "Coloc.count", "Membership.count" ], 1 do
      post api_colocs_path, params: { name: " Les Lilas ", address: " 1 rue des Lilas ", description: "  " }, as: :json
    end

    assert_response :created
    body = JSON.parse(response.body).fetch("coloc")
    assert_equal "Les Lilas", body.fetch("name")
    assert_equal "1 rue des Lilas", body.fetch("address")
    assert_nil body.fetch("description")
    assert_nil body.fetch("photo_url")
    assert_equal 1, body.fetch("member_count")
    assert_equal "Ada", body.fetch("members").first.fetch("first_name")
    assert body.fetch("invite_token").present?

    get api_colocs_path, as: :json
    assert_response :success
    assert_equal "Les Lilas", JSON.parse(response.body).fetch("colocs").first.fetch("name")
  end

  test "creates a coloc with a photo and a member can replace it" do
    post api_colocs_path, params: coloc_fields(photo: png_file), headers: requested_with
    assert_response :created
    body = JSON.parse(response.body).fetch("coloc")
    assert_includes body.fetch("photo_url"), "/rails/active_storage/representations/"

    patch api_coloc_path(body.fetch("id")),
      params: coloc_fields(description: "Nouveau texte", photo: png_file),
      headers: requested_with
    assert_response :success
    updated = JSON.parse(response.body).fetch("coloc")
    assert_equal "Nouveau texte", updated.fetch("description")
    assert updated.fetch("photo_url").present?

    patch api_coloc_path(body.fetch("id")), params: { remove_photo: true }, as: :json
    assert_response :success
    assert_nil JSON.parse(response.body).dig("coloc", "photo_url")
  end

  test "rejects a photo that is not an image" do
    assert_no_difference "Coloc.count" do
      post api_colocs_path, params: coloc_fields(photo: text_file), headers: requested_with
    end

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body).fetch("errors").join, "photo"
  end

  test "rejects a multipart upload without the requested-with header" do
    post api_colocs_path, params: coloc_fields(photo: png_file)
    assert_response :unsupported_media_type
  end

  test "hides a coloc from someone who is not a member" do
    coloc = create_coloc
    sign_in(create_user("guest@coloc.test"))

    get api_coloc_path(coloc), as: :json
    assert_response :forbidden

    patch api_coloc_path(coloc), params: { name: "Piratée" }, as: :json
    assert_response :forbidden
    assert_equal "Les Lilas", coloc.reload.name
  end

  test "joins through an invite link once" do
    coloc = create_coloc
    guest = create_user("guest@coloc.test")
    sign_in(guest)

    get api_invitation_path(coloc.invite_token), as: :json
    assert_response :success
    preview = JSON.parse(response.body).fetch("coloc")
    assert_equal "Les Lilas", preview.fetch("name")
    assert_not preview.key?("invite_token")
    assert_not preview.key?("members")

    assert_difference "Membership.count", 1 do
      post api_invitation_path(coloc.invite_token), as: :json
    end
    assert_response :created

    assert_no_difference "Membership.count" do
      post api_invitation_path(coloc.invite_token), as: :json
    end
    assert_response :success
    assert_equal 2, coloc.reload.memberships_count
  end

  test "refuses a 31st member" do
    coloc = create_coloc
    29.times { |index| coloc.add_member(create_user("member-#{index}@coloc.test")) }
    assert_equal 30, coloc.reload.memberships_count

    sign_in(create_user("late@coloc.test"))
    assert_no_difference "Membership.count" do
      post api_invitation_path(coloc.invite_token), as: :json
    end

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body).fetch("errors").join, "30"
  end

  test "regenerates the invite link and leaving removes access" do
    coloc = create_coloc
    old_token = coloc.invite_token

    post api_coloc_invitation_path(coloc), as: :json
    assert_response :success
    new_token = JSON.parse(response.body).dig("coloc", "invite_token")
    assert_not_equal old_token, new_token

    get api_invitation_path(old_token), as: :json
    assert_response :not_found

    delete api_coloc_membership_path(coloc), as: :json
    assert_response :no_content

    get api_coloc_path(coloc), as: :json
    assert_response :forbidden
  end

  private
    def create_user(email)
      User.create!(
        email: email,
        password: "secretpass",
        password_confirmation: "secretpass",
        first_name: "Ada",
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

    def coloc_fields(photo: nil, description: "Salon lumineux")
      { name: "Les Lilas", address: "1 rue des Lilas", description: description, photo: photo }.compact
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
