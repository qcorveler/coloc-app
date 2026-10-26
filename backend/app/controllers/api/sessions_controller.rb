module Api
  class SessionsController < ApplicationController
    skip_before_action :require_authentication, only: :create

    def show
      render json: { user: Current.user.as_json(host: request.base_url) }
    end

    def create
      user = User.find_by(email: params[:email].to_s.strip.downcase)

      if user&.authenticate(params[:password])
        start_new_session_for(user)
        render json: { user: user.as_json(host: request.base_url) }
      else
        render json: { errors: [ "Email ou mot de passe incorrect" ] }, status: :unauthorized
      end
    end

    def destroy
      terminate_session
      head :no_content
    end
  end
end
