class EventCancellation < ApplicationRecord
  belongs_to :event

  validates :occurrence_on, presence: { message: "est obligatoire" }, uniqueness: { scope: :event_id }
end
