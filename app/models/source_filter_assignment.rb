class SourceFilterAssignment < ApplicationRecord
  acts_as_tenant :account
  
  belongs_to :source_filter
  belongs_to :source
  
  validates :source_filter_id, uniqueness: { scope: [:account_id, :source_id] }
end