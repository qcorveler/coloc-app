module Api
  class PushSubscriptionsController < ApplicationController
    def show
      endpoint = params[:endpoint].to_s
      subscribed = endpoint.present? && Current.user.push_subscriptions.exists?(endpoint:)
      render json: {
        public_key: Rails.application.config.x.web_push.public_key,
        subscribed:
      }
    end

    def update
      subscription = PushSubscription.find_or_initialize_by(endpoint: params[:endpoint].to_s)
      subscription.user = Current.user
      subscription.p256dh = params[:p256dh]
      subscription.auth = params[:auth]
      if subscription.save
        head :no_content
      else
        render json: { errors: subscription.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      Current.user.push_subscriptions.where(endpoint: params[:endpoint].to_s).delete_all
      head :no_content
    end
  end
end
