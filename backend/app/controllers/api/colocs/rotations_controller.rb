module Api
  module Colocs
    class RotationsController < ApplicationController
      include ColocScoped

      def create
        rotation = @coloc.rotations.new
        save_rotation(rotation, status: :created)
      rescue Calendar::Error => error
        render json: { errors: [ error.message ] }, status: :unprocessable_entity
      end

      def update
        rotation = @coloc.rotations.find(params[:id])
        save_rotation(rotation, status: :ok)
      rescue Calendar::Error => error
        render json: { errors: [ error.message ] }, status: :unprocessable_entity
      end

      def destroy
        @coloc.rotations.find(params[:id]).destroy!
        head :no_content
      end

      private
        def save_rotation(rotation, status:)
          saved = rotation.reschedule(
            title: params[:title],
            starts_on: parse_date(:starts_on, "La date de début"),
            ends_on: nil,
            turn_days: parse_count(:turn_days, minimum: 1, label: "La durée d'un passage"),
            offset_days: parse_count(:offset_days, minimum: 0, label: "La pause"),
            member_ids:
          )
          if saved
            render json: { rotation: rotation.as_rule }, status:
          else
            render json: { errors: rotation.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def parse_date(key, label)
          raw = params[key]
          raise Calendar::Error, "#{label} est obligatoire" if raw.blank?

          Date.iso8601(raw.to_s)
        rescue Date::Error
          raise Calendar::Error, "#{label} est invalide"
        end

        def parse_count(key, minimum:, label:)
          raw = params[key]
          raise Calendar::Error, "#{label} est obligatoire" if raw.nil? || raw == ""

          value = Integer(raw, exception: false)
          return value if value && value >= minimum && value <= 366

          raise Calendar::Error, "#{label} est invalide"
        end

        def member_ids
          Array(params[:member_ids]).map(&:to_i).reject(&:zero?)
        end
    end
  end
end
