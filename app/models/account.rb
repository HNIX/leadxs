class Account < ApplicationRecord
  has_prefix_id :acct

  include Billing
  include Domains
  include Transfer

  belongs_to :owner, class_name: "User"
  has_many :account_invitations, dependent: :destroy
  has_many :account_users, dependent: :destroy
  has_many :notification_mentions, as: :record, dependent: :destroy, class_name: "Noticed::Event"
  has_many :account_notifications, dependent: :destroy, class_name: "Noticed::Event"
  has_many :users, through: :account_users
  has_many :companies, dependent: :destroy
  has_many :verticals, dependent: :destroy
  has_many :campaigns, dependent: :destroy
  has_many :sources, dependent: :destroy
  has_many :api_requests, dependent: :destroy
  has_many :distributions, dependent: :destroy
  has_many :validation_rules, dependent: :destroy
  has_many :bid_requests, dependent: :destroy
  has_many :bids, dependent: :destroy
  has_many :bid_analytic_snapshots, dependent: :destroy
  has_many :standard_fields, -> { order(position: :asc) }, dependent: :destroy
  has_many :compliance_records, dependent: :destroy
  has_many :consent_records, dependent: :destroy
  has_many :data_access_records, dependent: :destroy

  scope :personal, -> { where(personal: true) }
  scope :team, -> { where(personal: false) }
  scope :sorted, -> { order(personal: :desc, name: :asc) }

  has_one_attached :avatar

  validates :avatar, resizable_image: true
  validates :name, presence: true

  def team?
    !personal?
  end

  def personal_account_for?(user)
    personal? && owner?(user)
  end

  def owner?(user)
    owner_id == user&.id
  end
end
