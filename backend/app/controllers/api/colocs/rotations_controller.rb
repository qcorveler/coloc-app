module Api
  module Colocs
    class RotationsController < ApplicationController
      include ColocScoped

      def create
        rotation = @coloc.rotations.new
        save_rotation(rotation, reanchor: false, status: :created)
      rescue Calendar::Error => error
        render json: { errors: [ error.message ] }, status: :unprocessable_entity
      end

      def update
        rotation = @coloc.rotations.find(params[:id])
        ids = member_ids
        anchor = parse_anchor
        order_changed = ids != rotation.rotation_members.order(:position).pluck(:user_id)
        anchor_changed = anchor.beginning_of_week(:monday) != rotation.anchor_on
        save_rotation(rotation, reanchor: order_changed && !anchor_changed, status: :ok)
      rescue Calendar::Error => error
        render json: { errors: [ error.message ] }, status: :unprocessable_entity
      end

      def destroy
        @coloc.rotations.find(params[:id]).destroy!
        head :no_content
      end

      private
        def save_rotation(rotation, reanchor:, status:)
          saved = rotation.reschedule(
            title: params[:title],
            anchor_on: parse_anchor,
            member_ids:,
            reanchor:
          )
          if saved
            render json: { rotation: rotation.as_rule }, status:
          else
            render json: { errors: rotation.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def parse_anchor
          raise Calendar::Error, "La date de début est obligatoire" if params[:anchor_on].blank?

          Date.iso8601(params[:anchor_on].to_s)
        rescue Date::Error
          raise Calendar::Error, "La date de début est invalide"
        end

        def member_ids
          Array(params[:member_ids]).map(&:to_i).reject(&:zero?)
        end
    end
  end
end
