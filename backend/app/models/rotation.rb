class Rotation < ApplicationRecord
  belongs_to :coloc
  has_many :rotation_members, -> { order(:position) }, dependent: :destroy, inverse_of: :rotation
  has_many :users, through: :rotation_members

  attr_accessor :pending_member_ids

  normalizes :title, with: ->(title) { title.strip }

  validates :title, presence: { message: "est obligatoire" }, length: { maximum: 80, message: "est trop long (80 caractères maximum)" }
  validates :anchor_on, presence: { message: "est obligatoire" }
  validate :anchor_on_is_monday
  validate :members_are_valid

  def reschedule(title:, anchor_on:, member_ids:, reanchor:)
    self.title = title
    self.anchor_on = resolve_anchor(anchor_on, reanchor)
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
      update!(anchor_on: Date.current.beginning_of_week(:monday))
      rotation_members.delete_all
      remaining.each_with_index do |user_id, position|
        rotation_members.create!(user_id:, position:)
      end
    end
  end

  def weeks_between(from, to)
    members = rotation_members.includes(:user).sort_by(&:position)
    return [] if members.empty? || anchor_on.blank?

    week = from.beginning_of_week(:monday)
    week = anchor_on if week < anchor_on
    rows = []
    while week <= to
      member = members[((week - anchor_on).to_i / 7) % members.size]
      rows << week_json(week, member.user, members)
      week += 7
    end
    rows
  end

  def as_rule
    {
      id:,
      title:,
      anchor_on: anchor_on.iso8601,
      member_ids: rotation_members.order(:position).pluck(:user_id)
    }
  end

  def self.human_attribute_name(attribute, options = {})
    ATTRIBUTE_NAMES.fetch(attribute.to_sym) { super }
  end

  private

  ATTRIBUTE_NAMES = {
    title: "Le titre",
    anchor_on: "Le début"
  }.freeze

  def resolve_anchor(anchor_on, reanchor)
    return Date.current.beginning_of_week(:monday) if reanchor
    return if anchor_on.blank?

    anchor_on.beginning_of_week(:monday)
  end

  def anchor_on_is_monday
    return if anchor_on.blank? || anchor_on.monday?

    errors.add(:anchor_on, "doit être un lundi")
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

  def week_json(week, user, members)
    {
      id:,
      title:,
      starts_on: week.iso8601,
      ends_on: (week + 6).iso8601,
      anchor_on: anchor_on.iso8601,
      member_ids: members.map(&:user_id),
      user: { id: user.id, first_name: user.first_name, last_name: user.last_name }
    }
  end
end
