class DataAccessRecord < ApplicationRecord
  acts_as_tenant :account
  
  belongs_to :account
  belongs_to :user
  belongs_to :record, polymorphic: true, optional: false
  
  validates :action, :accessed_at, presence: true
  
  # Common actions
  VIEW = "view"
  EXPORT = "export"
  SEARCH = "search"
  DOWNLOAD = "download"
  PRINT = "print"
  
  # Common contexts
  ADMIN = "admin"
  DASHBOARD = "dashboard"
  API = "api"
  REPORTING = "reporting"
  COMPLIANCE = "compliance"
  AUDIT = "audit"
  CUSTOMER_SUPPORT = "customer_support"
  
  before_validation :set_accessed_at
  
  # Scopes
  scope :recent, -> { order(accessed_at: :desc) }
  scope :by_user, ->(user) { where(user_id: user.id) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_purpose, ->(purpose) { where(purpose: purpose) }
  scope :for_record, ->(record) { where(record_type: record.class.name, record_id: record.id) }
  scope :in_range, ->(start_date, end_date) { where(accessed_at: start_date..end_date) }
  scope :with_context, ->(context) { where(access_context: context) }
  
  # Generate a report of data access for a given period
  def self.generate_access_report(account, start_date, end_date)
    records = DataAccessRecord.in_range(start_date, end_date)
    
    report = {
      period_start: start_date,
      period_end: end_date,
      total_access_events: records.count,
      access_by_user: {},
      access_by_record_type: {},
      access_by_action: {},
      access_by_context: {}
    }
    
    # Group by user
    records.group(:user_id).count.each do |user_id, count|
      user = User.find_by(id: user_id)
      report[:access_by_user][user&.name || "Unknown User"] = count
    end
    
    # Group by record type
    records.group(:record_type).count.each do |record_type, count|
      report[:access_by_record_type][record_type] = count
    end
    
    # Group by action
    records.group(:action).count.each do |action, count|
      report[:access_by_action][action] = count
    end
    
    # Group by context
    records.group(:access_context).count.each do |context, count|
      report[:access_by_context][context || "Unknown"] = count
    end
    
    report
  end
  
  # Class method to easily record data access
  def self.record_access(record, action, user, options = {})
    # Get the account from the options, Current.account, or try to determine from user's associations
    account = options[:account] || 
              Current.account || 
              (user.respond_to?(:current_account) ? user.current_account : nil) ||
              (user.respond_to?(:accounts) && user.accounts.any? ? user.accounts.first : nil) ||
              (record.respond_to?(:account) ? record.account : nil)
    
    # Raise error if we couldn't determine the account
    unless account
      Rails.logger.error("Unable to determine account for data access record. User: #{user.id}, Record: #{record.class.name} #{record.id}")
      return nil
    end
    
    create!({
      record: record,
      action: action,
      user: user,
      account: account,
      purpose: options[:purpose],
      ip_address: options[:ip_address] || Current.request&.ip,
      user_agent: options[:user_agent] || Current.request&.user_agent,
      fields_accessed: options[:fields] || [],
      access_context: options[:context],
      accessed_at: Time.current
    })
  end
  
  private
  
  def set_accessed_at
    self.accessed_at ||= Time.current
  end
end
