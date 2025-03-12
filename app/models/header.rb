class Header < ApplicationRecord
  belongs_to :distribution
  
  validates :name, presence: true, uniqueness: { scope: :distribution_id }
  validates :value, presence: true
  
  # Common HTTP headers for convenience
  def self.common_headers
    [
      "Accept",
      "Accept-Encoding",
      "Accept-Language",
      "Authorization",
      "Cache-Control",
      "Content-Type",
      "Cookie",
      "Origin",
      "Referer",
      "User-Agent",
      "X-API-Key",
      "X-Auth-Token",
      "X-Client-ID",
      "X-Custom-Header",
      "X-Forwarded-For",
      "X-Lead-ID",
      "X-Requested-With",
      "X-Source-ID",
      "X-Transaction-ID"
    ]
  end
  
  # Get header value with fallback for safer display
  def value_or_placeholder
    value.presence || "[Not set]"
  end
end
