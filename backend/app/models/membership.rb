class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :coloc, counter_cache: true

  validates :user_id, uniqueness: { scope: :coloc_id }
end
