class Membership < ApplicationRecord
  def self.hsl_hex(hue, saturation, lightness)
    chroma = (1 - (2 * (lightness / 100.0) - 1).abs) * (saturation / 100.0)
    sector = hue / 60.0
    mix = chroma * (1 - ((sector % 2) - 1).abs)
    shift = (lightness / 100.0) - (chroma / 2.0)
    red, green, blue = case sector.floor
    when 0 then [ chroma, mix, 0 ]
    when 1 then [ mix, chroma, 0 ]
    when 2 then [ 0, chroma, mix ]
    when 3 then [ 0, mix, chroma ]
    when 4 then [ mix, 0, chroma ]
    else [ chroma, 0, mix ]
    end
    format("#%02x%02x%02x", ((red + shift) * 255).round, ((green + shift) * 255).round, ((blue + shift) * 255).round)
  end

  COLORS = Array.new(Coloc::MAX_MEMBERS) { |index| hsl_hex((index * 137.508) % 360, 58, 40) }.freeze

  belongs_to :user
  belongs_to :coloc, counter_cache: true

  before_validation :assign_default_color, on: :create

  validates :user_id, uniqueness: { scope: :coloc_id }
  validates :arrived_on, presence: { message: "est obligatoire" }
  validates :color, uniqueness: { scope: :coloc_id, message: "est déjà prise" }
  validate :arrived_on_cannot_be_in_the_future
  validate :color_known

  after_destroy :remove_from_rotations
  after_destroy :remove_event_reminders

  def self.human_attribute_name(attribute, options = {})
    ATTRIBUTE_NAMES.fetch(attribute.to_sym) { super }
  end

  private

  ATTRIBUTE_NAMES = {
    arrived_on: "La date d'arrivée",
    color: "La couleur"
  }.freeze

  def assign_default_color
    return if color.present?

    taken = coloc ? coloc.memberships.where.not(id: id).pluck(:color) : []
    self.color = (COLORS - taken).first
  end

  def color_known
    if color.blank?
      errors.add(:color, "est obligatoire")
    elsif !COLORS.include?(color)
      errors.add(:color, "n'est pas disponible")
    end
  end

  def arrived_on_cannot_be_in_the_future
    return if arrived_on.blank?
    return if arrived_on <= Date.current

    errors.add(:arrived_on, "ne peut pas être dans le futur")
  end

  def remove_from_rotations
    Rotation.where(coloc_id:).find_each { |rotation| rotation.drop_member(user) }
  end

  def remove_event_reminders
    EventReminder.where(user_id:, event_id: Event.where(coloc_id:).select(:id)).delete_all
  end
end
