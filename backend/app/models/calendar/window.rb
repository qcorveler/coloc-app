module Calendar
  class Window
    def initialize(coloc, from:, to:, viewer: nil)
      @coloc = coloc
      @from = from
      @to = to
      @viewer = viewer
    end

    def payload
      {
        events: event_rows.sort_by { |row| [ row[:starts_at], row[:title] ] },
        rotations: rotation_rows.sort_by { |row| [ row[:starts_on], row[:title] ] }
      }
    end

    private
      def event_rows
        @coloc.events.roots.includes(:cancellations, :replacements, :event_reminders).flat_map { |event| expand(event) }
      end

      def expand(event)
        cancelled = event.cancellations.map(&:occurrence_on)
        replacements = event.replacements.index_by(&:replaces_on)
        seen = []
        rows = []

        event.occurrence_dates(@from, @to).each do |date|
          next if cancelled.include?(date)

          replacement = replacements[date]
          starts_at, ends_at = replacement ? [ replacement.starts_at, replacement.ends_at ] : event.occurrence_range(date)
          next unless overlaps?(starts_at, ends_at)

          seen << date
          rows << event_json(event, replacement || event, date, starts_at, ends_at)
        end

        replacements.each do |date, replacement|
          next if seen.include?(date) || cancelled.include?(date)
          next unless overlaps?(replacement.starts_at, replacement.ends_at)

          rows << event_json(event, replacement, date, replacement.starts_at, replacement.ends_at)
        end

        rows
      end

      def event_json(event, source, date, starts_at, ends_at)
        {
          id: event.id,
          occurrence_on: date.iso8601,
          title: source.title,
          notes: source.notes,
          all_day: source.all_day,
          starts_at: starts_at.iso8601,
          ends_at: ends_at.iso8601,
          recurring: event.recurring?,
          recurrence: event.recurrence,
          weekdays: event.weekday_numbers,
          until_on: event.until_on&.iso8601,
          series_starts_at: event.starts_at.iso8601,
          series_ends_at: event.ends_at.iso8601,
          series_title: event.title,
          series_notes: event.notes,
          series_all_day: event.all_day,
          color: membership_colors[source.created_by_id],
          created_by_id: event.created_by_id,
          remind_user_ids: reminder_user_ids(event, "selected"),
          subscribed: @viewer.present? && reminder_user_ids(event, "subscribed").include?(@viewer.id)
        }
      end

      def rotation_rows
        colors = membership_colors
        @coloc.rotations.includes(rotation_members: :user).flat_map { |rotation|
          rotation.slots_between(@from, @to, colors:)
        }
      end

      def reminder_user_ids(event, source)
        event.event_reminders.select { |reminder| reminder.source == source }.map(&:user_id)
      end

      def membership_colors
        @membership_colors ||= @coloc.memberships.pluck(:user_id, :color).to_h
      end

      def overlaps?(starts_at, ends_at)
        starts_at < (@to + 1).in_time_zone.beginning_of_day && ends_at > @from.in_time_zone.beginning_of_day
      end
  end
end
