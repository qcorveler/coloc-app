class Rotation < ApplicationRecord
  belongs_to :coloc
  has_many :rotation_members, -> { order(:position) }, dependent: :destroy, inverse_of: :rotation
  has_many :users, through: :rotation_members

  attr_accessor :pending_member_ids

  normalizes :title, with: ->(title) { title.strip }

  validates :title, presence: { message: "est obligatoire" }, length: { maximum: 80, message: "est trop long (80 caractères maximum)" }
  validates :starts_on, presence: { message: "est obligatoire" }
  validates :turn_days, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 366, message: "doit être entre 1 et 366 jours" }
  validates :offset_days, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 366, message: "doit être entre 0 et 366 jours" }
  validate :ends_not_before_start
  validate :members_are_valid

  def reschedule(title:, starts_on:, ends_on:, turn_days:, offset_days:, member_ids:)
    self.title = title
    self.starts_on = starts_on
    self.ends_on = ends_on
    self.turn_days = turn_days
    self.offset_days = offset_days
    self.pending_member_ids = Array(member_ids).map(&:to_i)
    return false unless valid?

    transaction do
      save!
      rotation_members.delete_all
      pending_member_ids.each_with_index do |user_id, position|
        rotation_members.create!(user_id:, position:)
      end
    end
    true
  end

  def drop_member(user)
    ids = rotation_members.order(:position).pluck(:user_id)
    return unless ids.include?(user.id)

    remaining = ids - [ user.id ]
    transaction do
      rotation_members.delete_all
      remaining.each_with_index do |user_id, position|
        rotation_members.create!(user_id:, position:)
      end
    end
  end

  def slots_between(from, to)
    members = rotation_members.includes(:user).sort_by(&:position)
    return [] if members.empty? || starts_on.blank? || turn_days.to_i < 1 || offset_days.to_i.negative?

    horizon = ends_on || to
    return [] if starts_on > horizon || horizon < from || starts_on > to

    step = turn_days + offset_days
    index = 0
    cursor = starts_on
    if cursor < from
      earliest = from - (turn_days - 1)
      if earliest > starts_on
        index = ((earliest - starts_on).to_i + step - 1) / step
        cursor = starts_on + (index * step)
      end
    end

    rows = []
    guard = 0
    while cursor <= horizon && cursor <= to && guard < 1000
      guard += 1
      full_end = cursor + turn_days - 1
      slot_end = ends_on && full_end > ends_on ? ends_on : full_end
      if slot_end >= from && cursor <= to
        member = members[index % members.size]
        rows << slot_json(cursor, slot_end, member.user, members)
      end
      break if ends_on && full_end >= ends_on
      break if step <= 0

      cursor += step
      index += 1
    end
    rows
  end

  def as_rule
    {
      id:,
      title:,
      starts_on: starts_on.iso8601,
      ends_on: ends_on&.iso8601,
      turn_days:,
      offset_days:,
      member_ids: rotation_members.order(:position).pluck(:user_id)
    }
  end

  def self.human_attribute_name(attribute, options = {})
    ATTRIBUTE_NAMES.fetch(attribute.to_sym) { super }
  end

  private

  ATTRIBUTE_NAMES = {
    title: "Le titre",
    starts_on: "La date de début",
    ends_on: "La date de fin",
    turn_days: "La durée d'un passage",
    offset_days: "La pause"
  }.freeze

  def ends_not_before_start
    return if ends_on.blank? || starts_on.blank? || ends_on >= starts_on

    errors.add(:ends_on, "ne peut pas être avant le début")
  end

  def members_are_valid
    return if pending_member_ids.nil?

    ids = pending_member_ids
    if ids.empty?
      errors.add(:base, "Le tour doit désigner au moins une personne")
      return
    end
    if ids.uniq.size != ids.size
      errors.add(:base, "Une personne ne peut apparaître qu'une fois")
      return
    end
    return if coloc && coloc.users.where(id: ids).count == ids.size

    errors.add(:base, "Chaque personne doit faire partie de la coloc")
  end

  def slot_json(cursor, slot_end, user, members)
    {
      id:,
      title:,
      starts_on: cursor.iso8601,
      ends_on: slot_end.iso8601,
      rule_starts_on: starts_on.iso8601,
      rule_ends_on: ends_on&.iso8601,
      turn_days:,
      offset_days:,
      member_ids: members.map(&:user_id),
      user: { id: user.id, first_name: user.first_name, last_name: user.last_name }
    }
  end
end
