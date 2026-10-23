module Api
  module Colocs
    class EventsController < ApplicationController
      include ColocScoped

      def create
        event = @coloc.events.new(parsed_attributes)
        event.created_by = Current.user
        save_event(event, :created)
      rescue Calendar::Error => error
        render json: { errors: [ error.message ] }, status: :unprocessable_entity
      end

      def update
        event = @coloc.events.roots.find(params[:id])
        target = nil
        Event.transaction do
          target = target_for(event)
          target.assign_attributes(parsed_attributes)
          apply_occurrence_override(target, event) if target != event
          raise ActiveRecord::Rollback unless target.save
        end

        if target.errors.empty?
          render json: { event: event_json(target) }
        else
          render json: { errors: target.errors.full_messages }, status: :unprocessable_entity
        end
      rescue Calendar::Error => error
        render json: { errors: [ error.message ] }, status: :unprocessable_entity
      end

      def destroy
        event = @coloc.events.roots.find(params[:id])
        if params[:occurrence].present? && event.recurring?
          event.cancel_occurrence!(occurrence_date(event))
        else
          event.destroy!
        end
        head :no_content
      rescue Calendar::Error => error
        render json: { errors: [ error.message ] }, status: :unprocessable_entity
      end

      private
        def save_event(event, status)
          if event.save
            render json: { event: event_json(event) }, status: status
          else
            render json: { errors: event.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def target_for(event)
          return event if params[:occurrence].blank? || !event.recurring?

          date = occurrence_date(event)
          event.cancellations.where(occurrence_on: date).delete_all
          event.replacements.find_or_initialize_by(replaces_on: date) do |replacement|
            replacement.coloc = @coloc
            replacement.created_by = Current.user
          end
        end

        def apply_occurrence_override(target, event)
          target.recurrence = "none"
          target.weekdays = 0
          target.until_on = nil
          target.replaces_event = event
          target.replaces_on = occurrence_date(event)
          target.coloc = @coloc
        end

        def occurrence_date(event)
          date = Date.iso8601(params[:occurrence].to_s)
          raise Calendar::Error, "Cette occurrence est introuvable" unless event.occurs_on?(date)

          date
        rescue Date::Error
          raise Calendar::Error, "Cette occurrence est introuvable"
        end

        def parsed_attributes
          all_day = ActiveModel::Type::Boolean.new.cast(params[:all_day]) == true
          recurrence = params[:recurrence].presence || "none"
          {
            title: params[:title],
            notes: params[:notes],
            all_day:,
            starts_at: parse_time(params[:starts_at], all_day:, finish: false),
            ends_at: parse_time(params[:ends_at], all_day:, finish: true),
            recurrence:,
            weekdays: recurrence == "weekly" ? weekday_mask : 0,
            until_on: parse_until
          }
        end

        def parse_time(value, all_day:, finish:)
          raise Calendar::Error, "La date est obligatoire" if value.blank?

          if all_day
            date = Date.iso8601(value.to_s[0, 10])
            time = date.in_time_zone.beginning_of_day
            finish ? time + 1.day : time
          else
            time = Time.zone.parse(value.to_s)
            raise Calendar::Error, "La date est invalide" if time.nil?

            time
          end
        rescue Date::Error
          raise Calendar::Error, "La date est invalide"
        end

        def parse_until
          return if params[:until_on].blank?

          Date.iso8601(params[:until_on].to_s)
        rescue Date::Error
          raise Calendar::Error, "La date de fin est invalide"
        end

        def weekday_mask
          days = Array(params[:weekdays]).map(&:to_i)
          raise Calendar::Error, "Les jours choisis sont invalides" if days.any? { |day| !day.between?(1, 7) }

          days.uniq.sum { |day| Event.bit_for(day) }
        end

        def event_json(event)
          {
            id: event.id,
            title: event.title,
            notes: event.notes,
            all_day: event.all_day,
            starts_at: event.starts_at.iso8601,
            ends_at: event.ends_at.iso8601,
            recurrence: event.recurrence,
            weekdays: event.weekday_numbers,
            until_on: event.until_on&.iso8601,
            replaces_event_id: event.replaces_event_id,
            replaces_on: event.replaces_on&.iso8601
          }
        end
    end
  end
end
