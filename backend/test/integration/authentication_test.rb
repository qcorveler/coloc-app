require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    https!
  end

  test "signup creates a user and starts a session" do
    assert_difference [ "User.count", "Session.count" ], 1 do
      post api_users_path, params: valid_user, as: :json
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "ada@coloc.test", body.dig("user", "email")
    assert_equal "Ada", body.dig("user", "first_name")
    assert_not body.dig("user").key?("password_digest")
    assert cookies[:session_id].present?

    get api_session_path, as: :json

    assert_response :success
    assert_equal "ada@coloc.test", JSON.parse(response.body).dig("user", "email")
  end

  test "signup rejects invalid users" do
    assert_no_difference "User.count" do
      post api_users_path, params: {
        user: valid_user[:user].merge(password: "court", password_confirmation: "court", date_of_birth: Date.current.to_s)
      }, as: :json
    end

    assert_response :unprocessable_entity
    errors = JSON.parse(response.body).fetch("errors")
    assert errors.any? { |message| message.include?("mot de passe") }
    assert errors.any? { |message| message.include?("date de naissance") }
  end

  test "signup rejects a duplicate email" do
    post api_users_path, params: valid_user, as: :json
    assert_response :created

    assert_no_difference "User.count" do
      post api_users_path, params: valid_user, as: :json
    end

    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body).fetch("errors").join, "déjà utilisé"
  end

  test "signup rejects a non json body" do
    post api_users_path, params: valid_user

    assert_response :unsupported_media_type
  end

  test "login starts a session and logout ends it" do
    post api_users_path, params: valid_user, as: :json
    delete api_session_path, as: :json
    assert_response :no_content

    get api_session_path, as: :json
    assert_response :unauthorized

    post api_session_path, params: { email: "Ada@Coloc.test", password: "secretpass" }, as: :json

    assert_response :success
    assert_equal "ada@coloc.test", JSON.parse(response.body).dig("user", "email")

    get api_session_path, as: :json
    assert_response :success
  end

  test "login rejects unknown credentials" do
    post api_users_path, params: valid_user, as: :json

    post api_session_path, params: { email: "ada@coloc.test", password: "mauvais" }, as: :json

    assert_response :unauthorized
    assert_equal [ "Email ou mot de passe incorrect" ], JSON.parse(response.body).fetch("errors")
  end

  test "current user requires a session" do
    get api_session_path, as: :json

    assert_response :unauthorized
    assert_equal "Non authentifié", JSON.parse(response.body).fetch("error")
  end

  private
    def valid_user
      {
        user: {
          email: "Ada@Coloc.test",
          password: "secretpass",
          password_confirmation: "secretpass",
          first_name: "Ada",
          last_name: "Lovelace",
          date_of_birth: "1990-12-10"
        }
      }
    end
end
