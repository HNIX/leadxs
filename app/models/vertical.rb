class Vertical < AccountRecord
  # Associations
  acts_as_tenant :account

  # Validations
  validates :name, presence: true
  validates :name, uniqueness: {scope: :account_id}
  validates :primary_category, presence: true
  validates :archived, inclusion: {in: [true, false]}
  validates :base, inclusion: {in: [true, false]}

  # Scopes
  scope :active, -> { where(archived: false) }
  scope :archived, -> { where(archived: true) }
  scope :base, -> { where(base: true) }
  scope :custom, -> { where(base: false) }
  scope :sorted, -> { order(name: :asc) }
  scope :by_category, -> { order(primary_category: :asc, secondary_category: :asc) }

  # Constants
  PRIMARY_CATEGORIES = [
    "Insurance",
    "Home Services",
    "Finance",
    "Healthcare",
    "Education",
    "Legal",
    "Real Estate",
    "Automotive",
    "Travel",
    "Technology",
    "Business Services",
    "Energy"
  ].freeze

  # Class methods
  def self.primary_categories
    PRIMARY_CATEGORIES
  end

  # Instance methods
  def active?
    !archived
  end

  def archived?
    archived
  end

  def base?
    base
  end

  def custom?
    !base
  end

  def full_category
    if secondary_category.present?
      "#{primary_category} - #{secondary_category}"
    else
      primary_category
    end
  end
end
