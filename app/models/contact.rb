class Contact < AccountRecord
  acts_as_tenant :account
  # Associations
  belongs_to :company

  # Validations
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true, format: {with: URI::MailTo::EMAIL_REGEXP}
  validates :email, uniqueness: {scope: :account_id}

  # Scopes
  scope :sorted, -> { order(last_name: :asc, first_name: :asc) }

  # Methods
  def full_name
    "#{first_name} #{last_name}"
  end
end
