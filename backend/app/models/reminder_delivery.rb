class ReminderDelivery < ApplicationRecord
  SUBJECT_TYPES = %w[event rotation].freeze

  belongs_to :user

  validates :subject_type, inclusion: { in: SUBJECT_TYPES, message: "n'est pas reconnu" }
  validates :subject_id, :occurrence_on, presence: true
end
