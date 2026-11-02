module Api
  module Colocs
    class EventsController < ApplicationController
      include ColocScoped

      def create
        event = @coloc.events.new(parsed_attributes)
        event.created_by = Current.user
        saved = false
        Event.transaction do
          saved = event.save
          raise ActiveRecord::Rollback unless saved

          assign_selected_reminders!(event)
        end
        save_event(event, saved, :created)
      rescue Calendar::ReminderForbidden
        render json: { error: "Seul le créateur choisit qui prévenir" }, status: :forbidden
      rescue Calendar::Error => error
        render json: { errors: [ error.message ] }, status: :unprocessable_entity
      end

      def update
        event = @coloc.events.roots.find(params[:id])
        target = nil
        saved = false
        Event.transaction do
          target = target_for(event)
          target.assign_attributes(parsed_attributes)
          apply_occurrence_override(target, event) if target != event
          saved = target.save
          raise ActiveRecord::Rollback unless saved

          assign_selected_reminders!(event) if target == event
        end
        save_event(target, saved, :ok)
      rescue Calendar::ReminderForbidden
        render json: { error: "Seul le créateur choisit qui prévenir" }, status: :forbidden
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
        def save_event(event, saved, status)
          if saved
            render json: { event: event_json(event) }, status: status
          else
            render json: { errors: event.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def assign_selected_reminders!(event)
          return unless params.key?(:remind_user_ids)
          raise Calendar::ReminderForbidden unless event.created_by_id == Current.user.id

          ids = reminder_user_ids
          raise Calendar::Error, "Chaque personne doit faire partie de la coloc" unless @coloc.users.where(id: ids).count == ids.size

          event.replace_selected_reminders!(ids)
        end

        def reminder_user_ids
          ids = Array(params[:remind_user_ids]).map { |value| Integer(value, exception: false) }
          if ids.any?(&:nil?) || ids.any? { |id| id <= 0 }
            raise Calendar::Error, "Chaque personne doit faire partie de la coloc"
          end

          ids.uniq
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
            weekdays: %w[weekly biweekly].include?(recurrence) ? weekday_mask : 0,
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
            replaces_on: event.replaces_on&.iso8601,
            remind_user_ids: event.event_reminders.where(source: "selected").order(:user_id).pluck(:user_id)
          }
        end
    end
  end
end
