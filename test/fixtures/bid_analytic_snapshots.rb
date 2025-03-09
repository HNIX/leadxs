# This file provides a safe factory method for creating BidAnalyticSnapshot instances in tests

# Override BidAnalyticSnapshot.new to ensure metrics is always set
class BidAnalyticSnapshot
  class << self
    alias_method :original_new, :new
    
    def new(attributes = {})
      attributes[:metrics] ||= {}
      original_new(attributes)
    end
  end
end