module Api
  module Colocs
    class MembershipsController < ApplicationController
      include ColocScoped

      def destroy
        Current.user.memberships.find_by!(coloc: @coloc).destroy!
        head :no_content
      end
    end
  end
end
