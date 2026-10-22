module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
  end

  private
    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      session_id = cookies.signed[:session_id]
      return if session_id.blank?

      Session.find_by(id: session_id)
    end

    def request_authentication
      render json: { error: "Non authentifié" }, status: :unauthorized
    end

    def start_new_session_for(user)
      user.sessions.create!(
        user_agent: request.user_agent,
        ip_address: request.remote_ip
      ).tap do |session|
        Current.session = session
        cookies.signed.permanent[:session_id] = {
          value: session.id,
          httponly: true,
          same_site: :none,
          secure: true
        }
      end
    end

    def terminate_session
      Current.session&.destroy
      cookies.delete(:session_id, httponly: true, same_site: :none, secure: true)
    end
end
