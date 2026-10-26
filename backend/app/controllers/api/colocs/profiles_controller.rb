module Api
  module Colocs
    class ProfilesController < ApplicationController
      include ColocScoped

      def show
        membership = membership_for(params[:id])
        return render json: { error: "Introuvable" }, status: :not_found unless membership

        render json: { profile: membership.user.profile_json(host: request.base_url, arrived_on: membership.arrived_on) }
      end

      def update
        membership = membership_for(params[:id])
        return render json: { error: "Introuvable" }, status: :not_found unless membership
        return render json: { error: "Accès refusé" }, status: :forbidden unless membership.user_id == Current.user.id

        user = membership.user
        user.avatar.purge if remove_avatar? && params[:avatar].blank?
        membership.arrived_on = params[:arrived_on] if params.key?(:arrived_on)

        saved = User.transaction do
          user.assign_attributes(user_attributes)
          user_ok = user.valid?
          membership_ok = membership.valid?
          unless user_ok && membership_ok
            raise ActiveRecord::Rollback
          end

          user.save!
          membership.save!
          true
        end

        if saved
          render json: {
            profile: user.reload.profile_json(host: request.base_url, arrived_on: membership.reload.arrived_on)
          }
        else
          render json: { errors: user.errors.full_messages + membership.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private
        def membership_for(user_id)
          @coloc.memberships.includes(:user).find_by(user_id:)
        end

        def user_attributes
          permitted = params.permit(:first_name, :last_name, :description, :mood, :pronouns, :date_of_birth, :avatar)
          permitted.delete(:avatar) if permitted[:avatar].blank?
          permitted
        end

        def remove_avatar?
          ActiveModel::Type::Boolean.new.cast(params[:remove_avatar])
        end
    end
  end
end
