class Header < ApplicationRecord
  belongs_to :distribution
  
  validates :name, presence: true, uniqueness: { scope: :distribution_id }
  validates :value, presence: true
  
  # Common HTTP headers for convenience
  def self.common_headers
    [
      "Authorization",
      "Content-Type",
      "Accept",
      "User-Agent",
      "X-API-Key",
      "X-Requested-With"
    ]
  end
end
