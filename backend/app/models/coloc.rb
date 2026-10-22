class Coloc < ApplicationRecord
  MAX_MEMBERS = 30
  PHOTO_TYPES = %w[image/jpeg image/png image/webp].freeze

  has_secure_token :invite_token
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_one_attached :photo

  normalizes :name, with: ->(name) { name.strip }
  normalizes :address, with: ->(address) { address.strip }
  normalizes :description, with: ->(description) { description.strip.presence }

  validates :name, presence: { message: "est obligatoire" }
  validates :address, presence: { message: "est obligatoire" }
  validate :acceptable_photo

  def add_member(user)
    with_lock do
      existing = memberships.find_by(user: user)
      return existing if existing

      if memberships_count >= MAX_MEMBERS
        errors.add(:base, "Cette coloc est complète (30 personnes)")
        return nil
      end

      memberships.create!(user: user)
    end
  end

  def summary(host:)
    {
      id:,
      name:,
      address:,
      photo_url: photo_url_for(host),
      member_count: memberships_count
    }
  end

  def detail(host:)
    summary(host: host).merge(
      description:,
      invite_token:,
      members: users.order(:first_name, :last_name).map { |user|
        { id: user.id, first_name: user.first_name, last_name: user.last_name }
      }
    )
  end

  def self.human_attribute_name(attribute, options = {})
    ATTRIBUTE_NAMES.fetch(attribute.to_sym) { super }
  end

  private

  ATTRIBUTE_NAMES = {
    name: "Le nom",
    address: "L'adresse",
    description: "La description",
    photo: "La photo"
  }.freeze

  def acceptable_photo
    return unless photo.attached?

    unless PHOTO_TYPES.include?(photo.blob.content_type)
      errors.add(:photo, "doit être une image jpeg, png ou webp")
    end

    return if photo.blob.byte_size <= 5.megabytes

    errors.add(:photo, "est trop volumineuse (5 Mo maximum)")
  end

  def photo_url_for(host)
    return unless photo.attached?

    Rails.application.routes.url_helpers.rails_representation_url(
      photo.variant(resize_to_limit: [ 1600, 1600 ]),
      host: host
    )
  end
end
