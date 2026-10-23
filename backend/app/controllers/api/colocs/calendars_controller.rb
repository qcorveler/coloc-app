module Api
  module Colocs
    class CalendarsController < ApplicationController
      include ColocScoped

      def show
        from = Date.iso8601(params.require(:from))
        to = Date.iso8601(params.require(:to))
        if to < from
          return render json: { errors: [ "La période demandée est invalide" ] }, status: :unprocessable_entity
        end
        if (to - from).to_i > 61
          return render json: { errors: [ "La période demandée est trop longue" ] }, status: :unprocessable_entity
        end

        render json: Calendar::Window.new(@coloc, from:, to:).payload
      rescue Date::Error
        render json: { errors: [ "La période demandée est invalide" ] }, status: :unprocessable_entity
      end
    end
  end
end
