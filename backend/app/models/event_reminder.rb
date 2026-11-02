class EventReminder < ApplicationRecord
  SOURCES = %w[selected subscribed].freeze

  belongs_to :event
  belongs_to :user

  validates :source, inclusion: { in: SOURCES, message: "n'est pas reconnue" }
end
