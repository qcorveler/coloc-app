class Event < ApplicationRecord
  RECURRENCES = %w[none daily weekly monthly].freeze

  belongs_to :coloc
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :replaces_event, class_name: "Event", optional: true, inverse_of: :replacements
  has_many :cancellations, class_name: "EventCancellation", dependent: :destroy
  has_many :replacements, class_name: "Event", foreign_key: :replaces_event_id, dependent: :destroy, inverse_of: :replaces_event

  scope :roots, -> { where(replaces_event_id: nil) }

  normalizes :title, with: ->(title) { title.strip }
  normalizes :notes, with: ->(notes) { notes.strip.presence }

  validates :title, presence: { message: "est obligatoire" }, length: { maximum: 80, message: "est trop long (80 caractères maximum)" }
  validates :notes, length: { maximum: 2000, message: "est trop longue (2000 caractères maximum)" }, allow_nil: true
  validates :recurrence, inclusion: { in: RECURRENCES, message: "n'est pas reconnue" }
  validates :starts_at, :ends_at, presence: { message: "est obligatoire" }
  validate :ends_after_start
  validate :weekly_days_known
  validate :weekly_days_present
  validate :weekly_includes_start
  validate :until_on_after_start
  validate :replacement_is_single

  def recurring?
    recurrence != "none"
  end

  def self.bit_for(cwday)
    1 << (cwday.to_i - 1)
  end

  def weekday_numbers
    (1..7).select { |day| weekdays.to_i.anybits?(self.class.bit_for(day)) }
  end

  def occurs_on?(date)
    return false if starts_at.blank? || date < starts_at.to_date
    return false if until_on.present? && date > until_on

    case recurrence
    when "none" then date == starts_at.to_date
    when "daily" then true
    when "weekly" then weekdays.to_i.anybits?(self.class.bit_for(date.cwday))
    when "monthly" then date.day == starts_at.to_date.day
    else false
    end
  end

  def occurrence_dates(from, to)
    return [] if starts_at.blank? || ends_at.blank?

    duration = ends_at - starts_at
    earliest = (from.in_time_zone.beginning_of_day - duration).to_date
    range_start = [ starts_at.to_date, earliest ].max
    range_end = [ to, until_on ].compact.min
    return [] if range_start > range_end
    if recurrence == "none"
      date = starts_at.to_date
      return date.between?(range_start, range_end) && occurs_on?(date) ? [ date ] : []
    end

    date = range_start
    dates = []
    while date <= range_end
      dates << date if occurs_on?(date)
      date += 1
    end
    dates
  end

  def occurrence_range(date)
    day_offset = (ends_at.in_time_zone.to_date - starts_at.in_time_zone.to_date).to_i
    [ clock_on(starts_at, date), clock_on(ends_at, date + day_offset) ]
  end

  def cancel_occurrence!(date)
    transaction do
      replacements.where(replaces_on: date).destroy_all
      cancellations.find_or_create_by!(occurrence_on: date)
    end
  end

  def self.human_attribute_name(attribute, options = {})
    ATTRIBUTE_NAMES.fetch(attribute.to_sym) { super }
  end

  private

  ATTRIBUTE_NAMES = {
    title: "Le titre",
    notes: "Les notes",
    starts_at: "Le début",
    ends_at: "La fin",
    weekdays: "Les jours",
    until_on: "La date de fin",
    recurrence: "La répétition"
  }.freeze

  def ends_after_start
    return if starts_at.blank? || ends_at.blank? || ends_at > starts_at

    errors.add(:ends_at, "doit être après le début")
  end

  def weekly_days_known
    return if weekdays.to_i.between?(0, 127)

    errors.add(:weekdays, "sont invalides")
  end

  def weekly_days_present
    return unless recurrence == "weekly"
    return if weekdays.to_i.positive?

    errors.add(:weekdays, "doivent indiquer au moins un jour")
  end

  def weekly_includes_start
    return unless recurrence == "weekly" && starts_at.present?
    return if weekdays.to_i.anybits?(self.class.bit_for(starts_at.to_date.cwday))

    errors.add(:weekdays, "doivent inclure le jour de début")
  end

  def until_on_after_start
    return if until_on.blank? || starts_at.blank? || until_on >= starts_at.to_date

    errors.add(:until_on, "doit être après le début")
  end

  def replacement_is_single
    return if replaces_event_id.blank?

    errors.add(:replaces_on, "est obligatoire") if replaces_on.blank?
    errors.add(:recurrence, "ne s'applique pas à une occurrence modifiée") if recurrence != "none"
    return if replaces_event.nil? || replaces_event.coloc_id == coloc_id

    errors.add(:replaces_event, "appartient à une autre coloc")
  end

  def clock_on(time, date)
    clock = time.in_time_zone
    Time.zone.local(date.year, date.month, date.day, clock.hour, clock.min, clock.sec)
  end
end
