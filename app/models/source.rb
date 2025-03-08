class Source < AccountRecord
  # Associations
  acts_as_tenant :account
  belongs_to :campaign
  belongs_to :company
  
  # Constants
  STATUSES = ['active', 'paused', 'archived'].freeze
  INTEGRATION_TYPES = ['affiliate', 'web_form'].freeze
  PAYOUT_METHODS = ['fixed', 'percentage'].freeze
  PAYOUT_STRUCTURES = ['per_lead', 'per_action', 'per_click', 'per_call', 'per_conversion'].freeze
  
  # Validations
  validates :name, presence: true
  validates :name, uniqueness: { scope: :account_id }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :integration_type, presence: true, inclusion: { in: INTEGRATION_TYPES }
  validates :token, presence: true, uniqueness: true
  validates :payout_method, inclusion: { in: PAYOUT_METHODS }, allow_blank: true
  validates :payout_structure, inclusion: { in: PAYOUT_STRUCTURES }, allow_blank: true
  validates :payout, :margin, :minimum_acceptable_bid, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :daily_budget, :monthly_budget, numericality: { greater_than: 0 }, allow_nil: true
  
  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :paused, -> { where(status: 'paused') }
  scope :archived, -> { where(status: 'archived') }
  scope :affiliates, -> { where(integration_type: 'affiliate') }
  scope :web_forms, -> { where(integration_type: 'web_form') }
  
  # Callbacks
  before_validation :generate_token, on: :create
  
  # Instance methods
  def active?
    status == 'active'
  end
  
  def paused?
    status == 'paused'
  end
  
  def archived?
    status == 'archived'
  end
  
  def affiliate?
    integration_type == 'affiliate'
  end
  
  def web_form?
    integration_type == 'web_form'
  end
  
  def regenerate_token!
    update!(token: generate_secure_token)
  end
  
  def status_badge
    case status
    when 'active'
      { color: 'green', label: 'Active' }
    when 'paused'
      { color: 'yellow', label: 'Paused' }
    when 'archived'
      { color: 'gray', label: 'Archived' }
    else
      { color: 'gray', label: status.titleize }
    end
  end
  
  # Revenue and profit calculations
  def calculate_revenue(count = 1)
    return 0 unless payout.present?
    payout * count
  end
  
  def calculate_profit(bid_amount, count = 1)
    return 0 unless payout.present? && bid_amount.present?
    (bid_amount - payout) * count
  end
  
  private
  
  def generate_token
    self.token ||= generate_secure_token
  end
  
  def generate_secure_token
    loop do
      token = SecureRandom.urlsafe_base64(32)
      break token unless self.class.exists?(token: token)
    end
  end
end