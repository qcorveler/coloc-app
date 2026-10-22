module Api
  class InvitationsController < ApplicationController
    before_action :set_coloc

    def show
      render json: { coloc: @coloc.summary(host: request.base_url) }
    end

    def create
      membership = @coloc.add_member(Current.user)

      if membership.nil?
        render json: { errors: @coloc.errors.full_messages }, status: :unprocessable_entity
      elsif membership.previously_new_record?
        render json: { coloc: @coloc.reload.detail(host: request.base_url) }, status: :created
      else
        render json: { coloc: @coloc.reload.detail(host: request.base_url) }
      end
    end

    private
      def set_coloc
        @coloc = Coloc.find_by!(invite_token: params[:token])
      end
  end
end
