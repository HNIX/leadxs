class DistributionFilterAssignment < ApplicationRecord
  acts_as_tenant :account
  
  belongs_to :distribution_filter
  belongs_to :distribution
  
  validates :distribution_filter_id, uniqueness: { scope: [:account_id, :distribution_id] }
end