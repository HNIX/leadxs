class Vertical < AccountRecord
  # Associations
  acts_as_tenant :account

  #has_many :campaigns
  has_many :vertical_fields, -> { order(position: :asc) }, dependent: :destroy

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

  # Method to duplicate vertical with its fields
  def duplicate
    new_vertical = self.dup
    new_vertical.secondary_category = "#{secondary_category} (Copy)"
    
    transaction do
      new_vertical.save!
      
      # Duplicate all vertical fields
      vertical_fields.each do |field|
        new_field = field.dup
        new_field.vertical = new_vertical
        new_field.save!
        
        # Duplicate list values if any
        field.list_values.each do |list_value|
          new_list_value = list_value.dup
          new_list_value.list_owner = new_field
          new_list_value.save!
        end
      end
      
      new_vertical
    end
  end
end