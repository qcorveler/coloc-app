class CalendarRemindersJob < ApplicationJob
  queue_as :default

  retry_on Notifications::DeliveryError, wait: 5.minutes, attempts: 5

  def perform(date = Date.current + 1)
    date = Date.iso8601(date) if date.is_a?(String)

    Coloc.find_each do |coloc|
      remind_events(coloc, date)
      remind_rotations(coloc, date)
    end
  end

  private
    def remind_events(coloc, date)
      rows = Calendar::Window.new(coloc, from: date, to: date).payload.fetch(:events)
      return if rows.empty?

      events = coloc.events.roots.where(id: rows.map { |row| row[:id] }.uniq).includes(event_reminders: :user).index_by(&:id)
      rows.each do |row|
        event = events[row[:id]]
        next unless event

        event.event_reminders.map(&:user).uniq(&:id).each do |user|
          Notifications::Deliver.call(
            user:,
            title: "Demain : #{row[:title]}",
            body: coloc.name,
            path: "/colocs/#{coloc.id}/planning",
            subject_type: "event",
            subject_id: event.id,
            occurrence_on: date
          )
        end
      end
    end

    def remind_rotations(coloc, date)
      coloc.rotations.includes(rotation_members: :user).find_each do |rotation|
        rotation.slots_between(date, date).each do |slot|
          next unless slot[:starts_on] == date.iso8601

          member = rotation.rotation_members.find { |row| row.user_id == slot.dig(:user, :id) }
          next if member.nil?

          Notifications::Deliver.call(
            user: member.user,
            title: "Ton tour commence : #{slot[:title]}",
            body: coloc.name,
            path: "/colocs/#{coloc.id}/planning",
            subject_type: "rotation",
            subject_id: rotation.id,
            occurrence_on: date
          )
        end
      end
    end
end
