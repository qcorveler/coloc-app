module Notifications
  class Deliver
    def self.call(user:, title:, body:, path:, subject_type:, subject_id:, occurrence_on:)
      delivery = claim(user, subject_type, subject_id, occurrence_on)
      return unless delivery

      subscriptions = user.push_subscriptions.to_a
      return if subscriptions.empty?

      successes = 0
      transient = false
      subscriptions.each do |subscription|
        case subscription.deliver(title:, body:, path:)
        when :sent
          successes += 1
        when :transient
          transient = true
        end
      end
      return if successes.positive? || !transient

      delivery.destroy!
      raise DeliveryError, "L'envoi des notifications a échoué"
    end

    def self.claim(user, subject_type, subject_id, occurrence_on)
      ReminderDelivery.create!(user:, subject_type:, subject_id:, occurrence_on:)
    rescue ActiveRecord::RecordNotUnique
      nil
    end
    private_class_method :claim
  end
end
