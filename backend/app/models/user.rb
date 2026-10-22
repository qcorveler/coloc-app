class User < ApplicationRecord
  has_secure_password validations: false
  has_many :sessions, dependent: :destroy

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email,
    presence: { message: "est obligatoire" },
    uniqueness: { case_sensitive: false, message: "est déjà utilisé" },
    format: { with: URI::MailTo::EMAIL_REGEXP, message: "n'est pas valide" }
  validates :first_name, presence: { message: "est obligatoire" }
  validates :last_name, presence: { message: "est obligatoire" }
  validates :date_of_birth, presence: { message: "est obligatoire" }
  validates :password, presence: { message: "est obligatoire" }, on: :create
  validates :password,
    length: { minimum: 8, maximum: 72, message: "doit contenir entre 8 et 72 caractères" },
    confirmation: { message: "ne correspond pas" },
    allow_blank: true,
    on: :create
  validate :date_of_birth_must_be_in_the_past

  def as_json(options = {})
    super(options.merge(only: [ :id, :email, :first_name, :last_name, :date_of_birth ]))
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
    date_of_birth: "La date de naissance"
  }.freeze

  def date_of_birth_must_be_in_the_past
    return if date_of_birth.blank?
    return if date_of_birth < Date.current

    errors.add(:date_of_birth, "doit être dans le passé")
  end
end
