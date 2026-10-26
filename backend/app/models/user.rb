class User < ApplicationRecord
  AVATAR_TYPES = %w[image/jpeg image/png image/webp].freeze

  has_secure_password validations: false
  has_many :sessions, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :colocs, through: :memberships
  has_many :created_events, class_name: "Event", foreign_key: :created_by_id, dependent: :nullify
  has_many :rotation_members, dependent: :destroy
  has_one_attached :avatar

  normalizes :email, with: ->(email) { email.strip.downcase }
  normalizes :description, with: ->(description) { description.strip.presence }
  normalizes :mood, with: ->(mood) { mood.strip.presence }
  normalizes :pronouns, with: ->(pronouns) { pronouns.strip.presence }

  validates :email,
    presence: { message: "est obligatoire" },
    uniqueness: { case_sensitive: false, message: "est déjà utilisé" },
    format: { with: URI::MailTo::EMAIL_REGEXP, message: "n'est pas valide" }
  validates :first_name, presence: { message: "est obligatoire" }
  validates :last_name, presence: { message: "est obligatoire" }
  validates :date_of_birth, presence: { message: "est obligatoire" }
  validates :mood, length: { maximum: 40, message: "dépasse 40 caractères" }, allow_blank: true
  validates :pronouns, length: { maximum: 40, message: "dépassent 40 caractères" }, allow_blank: true
  validates :description, length: { maximum: 500, message: "dépasse 500 caractères" }, allow_blank: true
  validates :password, presence: { message: "est obligatoire" }, on: :create
  validates :password,
    length: { minimum: 8, maximum: 72, message: "doit contenir entre 8 et 72 caractères" },
    confirmation: { message: "ne correspond pas" },
    allow_blank: true,
    on: :create
  validate :date_of_birth_must_be_in_the_past
  validate :acceptable_avatar

  def as_json(options = {})
    options = options.dup
    host = options.delete(:host)
    payload = super(options.merge(only: [ :id, :email, :first_name, :last_name, :date_of_birth ]))
    payload["avatar_url"] = avatar_url(host) if host
    payload
  end

  def avatar_url(host)
    return unless avatar.attached?

    Rails.application.routes.url_helpers.rails_representation_url(
      avatar.variant(resize_to_fill: [ 400, 400 ]),
      host: host
    )
  end

  def profile_json(host:, arrived_on:)
    {
      id:,
      first_name:,
      last_name:,
      description:,
      mood:,
      pronouns:,
      date_of_birth:,
      arrived_on:,
      avatar_url: avatar_url(host)
    }
  end

  def self.human_attribute_name(attribute, options = {})
    ATTRIBUTE_NAMES.fetch(attribute.to_sym) { super }
  end

  private

  ATTRIBUTE_NAMES = {
    email: "L'email",
    password: "Le mot de passe",
    password_confirmation: "La confirmation du mot de passe",
    first_name: "Le prénom",
    last_name: "Le nom",
    date_of_birth: "La date de naissance",
    description: "La description",
    mood: "L'humeur",
    pronouns: "Les pronoms",
    avatar: "La photo"
  }.freeze

  def date_of_birth_must_be_in_the_past
    return if date_of_birth.blank?
    return if date_of_birth < Date.current

    errors.add(:date_of_birth, "doit être dans le passé")
  end

  def acceptable_avatar
    return unless avatar.attached?

    unless AVATAR_TYPES.include?(avatar.blob.content_type)
      errors.add(:avatar, "doit être une image jpeg, png ou webp")
    end

    return if avatar.blob.byte_size <= 5.megabytes

    errors.add(:avatar, "est trop volumineuse (5 Mo maximum)")
  end
end
