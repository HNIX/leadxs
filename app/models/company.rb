class Company < AccountRecord
  # Associations
  belongs_to :account
  
  # Validations
  validates :name, presence: true
  validates :name, uniqueness: { scope: :account_id }
  validates :status, inclusion: { in: %w[active inactive], allow_blank: true }
  
  # Scopes
  scope :active, -> { where(status: "active") }
  scope :inactive, -> { where(status: "inactive") }
  scope :sorted, -> { order(name: :asc) }
  
  # Constants
  BILLING_CYCLES = %w[weekly biweekly monthly quarterly annually].freeze
  CURRENCIES = %w[USD EUR GBP CAD AUD].freeze
  PAYMENT_TERMS = %w[net15 net30 net45 net60 due_on_receipt].freeze
  
  # Methods
  def active?
    status == "active"
  end
  
  def inactive?
    status == "inactive"
  end
  
  def status_badge
    case status
    when "active"
      { color: "green", label: "Active" }
    when "inactive"
      { color: "gray", label: "Inactive" }
    else
      { color: "gray", label: status.titleize }
    end
  end
end