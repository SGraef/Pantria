# frozen_string_literal: true
# typed: false

# A material or plan belonging to a project: a name plus any combination of
# link, file and cost -- all three optional, so a pure cost line ("Handwerker
# Anzahlung") works too. The project's actual cost sums over its items.
class ProjectItem < ApplicationRecord
  KINDS = %w[material plan].freeze

  # Same broad scan/export set the document uploader accepts.
  ACCEPTED_MIME_TYPES = Document::ACCEPTED_MIME_TYPES

  belongs_to :household
  belongs_to :project

  has_one_attached :file

  before_validation :inherit_household

  validates :kind, inclusion: { in: KINDS }
  validates :name, presence: true, length: { maximum: 200 }
  validates :cost_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                         allow_nil:    true
  validates :url, format: { with: %r{\Ahttps?://}i }, allow_blank: true, length: { maximum: 500 }
  # Items stay editable, so validate the type whenever a file is attached
  # (not only on create like Document).
  validate :file_must_be_supported_type

  scope :materials, -> { where(kind: "material") }
  scope :plans,     -> { where(kind: "plan") }

  # BigDecimal accessor pair over the cents column (Price#amount pattern).
  def cost
    cost_cents && (BigDecimal(cost_cents.to_s) / 100)
  end

  def cost=(value)
    self.cost_cents = value.blank? ? nil : (BigDecimal(value.to_s) * 100).to_i
  end

  private

  def inherit_household
    self.household ||= project&.household
  end

  def file_must_be_supported_type
    return unless file.attached?
    return if ACCEPTED_MIME_TYPES.include?(file.blob&.content_type)

    errors.add(:file, :invalid)
  end
end
