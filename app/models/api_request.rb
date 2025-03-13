class ApiRequest < ApplicationRecord
  acts_as_tenant :account
  
  # Use UUID as the primary key for API lookup
  def self.find_by_uuid(uuid)
    find_by(uuid: uuid)
  end
  
  belongs_to :requestable, polymorphic: true
  belongs_to :lead, optional: true
  
  before_validation :ensure_uuid
  
  enum :request_method, {
    get: 0,
    post: 1,
    put: 2,
    patch: 3
  }
  
  validates :endpoint_url, presence: true
  validates :request_method, presence: true
  
  store_accessor :request_payload, []
  store_accessor :response_data, []
  store_accessor :request_headers, []
  
  scope :recent, -> { order(created_at: :desc) }
  scope :successful, -> { where("response_code >= 200 AND response_code < 300") }
  scope :failed, -> { where("response_code < 200 OR response_code >= 300 OR error IS NOT NULL") }
  
  def successful?
    response_code.present? && response_code >= 200 && response_code < 300 && error.blank?
  end
  
  def failed?
    !successful?
  end
  
  def mark_as_sent
    update(sent_at: Time.current)
  end
  
  # Get formatted response data
  def response_data
    return {} if response_payload.blank?
    
    begin
      # Handle JSON responses
      if response_payload.is_a?(String) && response_payload.start_with?('{')
        JSON.parse(response_payload)
      else
        response_payload
      end
    rescue JSON::ParserError
      # Return as string if not valid JSON
      response_payload
    end
  end
  
  # Get the endpoint URL
  def endpoint
    endpoint_url
  end
  
  # Get the HTTP method used
  def method
    self.request_method.upcase
  end
  
  # Get the associated campaign
  def campaign
    if lead.present?
      lead.campaign
    elsif requestable.respond_to?(:campaign)
      requestable.campaign
    else
      nil
    end
  end
  
  # Override to_param to use UUID in URLs instead of ID
  def to_param
    uuid
  end

  private
  
  def ensure_uuid
    self.uuid ||= SecureRandom.uuid
  end
  
end
