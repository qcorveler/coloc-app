class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :coloc, counter_cache: true

  validates :user_id, uniqueness: { scope: :coloc_id }

  after_destroy :remove_from_rotations

  private

  def remove_from_rotations
    Rotation.where(coloc_id:).find_each { |rotation| rotation.drop_member(user) }
  end
end
