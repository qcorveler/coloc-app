module Api
  module Colocs
    class InvitationsController < ApplicationController
      include ColocScoped

      def create
        @coloc.regenerate_invite_token
        render json: { coloc: @coloc.detail(host: request.base_url) }
      end
    end
  end
end
