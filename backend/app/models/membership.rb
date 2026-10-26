class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :coloc, counter_cache: true

  validates :user_id, uniqueness: { scope: :coloc_id }
  validates :arrived_on, presence: { message: "est obligatoire" }
  validate :arrived_on_cannot_be_in_the_future

  after_destroy :remove_from_rotations

  def self.human_attribute_name(attribute, options = {})
    ATTRIBUTE_NAMES.fetch(attribute.to_sym) { super }
  end

  private

  ATTRIBUTE_NAMES = {
    arrived_on: "La date d'arrivée"
  }.freeze

  def arrived_on_cannot_be_in_the_future
    return if arrived_on.blank?
    return if arrived_on <= Date.current

    errors.add(:arrived_on, "ne peut pas être dans le futur")
  end

  def remove_from_rotations
    Rotation.where(coloc_id:).find_each { |rotation| rotation.drop_member(user) }
  end
end
