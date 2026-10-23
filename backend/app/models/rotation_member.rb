class RotationMember < ApplicationRecord
  belongs_to :rotation
  belongs_to :user

  validates :position, presence: true, uniqueness: { scope: :rotation_id }
  validates :user_id, uniqueness: { scope: :rotation_id }
end
