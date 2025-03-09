class BidAnalyticSnapshot < ApplicationRecord
  acts_as_tenant :account
  
  belongs_to :campaign, optional: true
  belongs_to :distribution, optional: true
  
  validates :period_start, :period_end, :period_type, presence: true
  
  # Add a before_validation callback to ensure metrics is always set
  before_validation :ensure_metrics
  
  def ensure_metrics
    self.metrics ||= {}
  end
  
  enum :period_type, {
    hourly: "hourly",
    daily: "daily",
    weekly: "weekly",
    monthly: "monthly"
  }

  scope :recent, -> { order(period_end: :desc) }
  scope :hourly_snapshots, -> { where(period_type: :hourly) }
  scope :daily_snapshots, -> { where(period_type: :daily) }
  scope :weekly_snapshots, -> { where(period_type: :weekly) }
  scope :monthly_snapshots, -> { where(period_type: :monthly) }
  scope :hourly, -> { where(period_type: :hourly) }
  
  scope :for_campaign, ->(campaign_id) { where(campaign_id: campaign_id) }
  scope :for_distribution, ->(distribution_id) { where(distribution_id: distribution_id) }
  scope :for_period, ->(start_date, end_date) { where("period_start >= ? AND period_end <= ?", start_date, end_date) }
  scope :for_account, ->(account) { where(account_id: account.id) }

  # Track bid conversion rate
  def conversion_rate
    return 0 if total_bids.zero?
    (conversion_count.to_f / total_bids) * 100
  end
  
  # Track bid acceptance rate
  def acceptance_rate
    return 0 if total_bids.zero?
    (accepted_bids.to_f / total_bids) * 100
  end
  
  # Calculate average revenue per bid
  def avg_revenue_per_bid
    return 0 if total_bids.zero?
    total_revenue.to_f / total_bids
  end
  
  # Calculate average revenue per accepted bid
  def avg_revenue_per_accepted_bid
    return 0 if accepted_bids.zero?
    total_revenue.to_f / accepted_bids
  end
  
  # Get the bid response rate
  def response_rate
    return 0 if metrics["bid_requests_sent"].to_i.zero?
    (total_bids.to_f / metrics["bid_requests_sent"].to_i) * 100
  end
  
  # Class methods for generating analytics
  class << self
    def generate_hourly_snapshot(account, end_time = Time.current)
      start_time = end_time - 1.hour
      generate_snapshot(account, start_time, end_time, :hourly)
    end
    
    def generate_daily_snapshot(account, end_date = Date.current)
      end_time = end_date.end_of_day
      start_time = end_date.beginning_of_day
      generate_snapshot(account, start_time, end_time, :daily)
    end
    
    def generate_weekly_snapshot(account, end_date = Date.current)
      end_time = end_date.end_of_week.end_of_day
      start_time = end_date.beginning_of_week.beginning_of_day
      generate_snapshot(account, start_time, end_time, :weekly)
    end
    
    def generate_monthly_snapshot(account, end_date = Date.current)
      end_time = end_date.end_of_month.end_of_day
      start_time = end_date.beginning_of_month.beginning_of_day
      generate_snapshot(account, start_time, end_time, :monthly)
    end
    
    def generate_snapshot(account, start_time, end_time, period_type, campaign_id = nil, distribution_id = nil)
      # Query bids for the period
      bid_scope = account.bids.where(created_at: start_time..end_time)
      
      # Apply filters if provided
      bid_scope = bid_scope.joins(:bid_request).where(bid_requests: { campaign_id: campaign_id }) if campaign_id
      bid_scope = bid_scope.where(distribution_id: distribution_id) if distribution_id
      
      # Calculate metrics
      total_bids = bid_scope.count
      accepted_bids = bid_scope.accepted.count
      rejected_bids = bid_scope.where(status: :rejected).count
      expired_bids = bid_scope.where(status: :expired).count
      
      # Amounts
      amounts = bid_scope.pluck(:amount).compact
      avg_amount = amounts.any? ? amounts.sum / amounts.size : 0
      max_amount = amounts.any? ? amounts.max : 0
      min_amount = amounts.any? ? amounts.min : 0
      
      # Revenue and conversions (implement based on your lead distribution logic)
      # This is a placeholder - implement based on your actual revenue tracking
      conversion_count = bid_scope.accepted.count
      total_revenue = bid_scope.accepted.sum(:amount)
      
      # Additional metrics
      metrics = {
        bid_requests_sent: account.bid_requests.where(created_at: start_time..end_time).count,
        avg_response_time: calculate_avg_response_time(bid_scope),
        time_to_expiration: calculate_time_to_expiration(account, start_time, end_time),
        distribution_stats: calculate_distribution_stats(bid_scope),
        campaign_stats: calculate_campaign_stats(bid_scope)
      }
      
      # Create the snapshot
      snapshot = account.bid_analytic_snapshots.create!(
        period_start: start_time,
        period_end: end_time,
        period_type: period_type,
        total_bids: total_bids,
        accepted_bids: accepted_bids,
        rejected_bids: rejected_bids,
        expired_bids: expired_bids,
        avg_bid_amount: avg_amount,
        max_bid_amount: max_amount,
        min_bid_amount: min_amount,
        conversion_count: conversion_count,
        total_revenue: total_revenue,
        metrics: metrics,
        campaign_id: campaign_id,
        distribution_id: distribution_id
      )
      
      # Broadcast the update to the real-time dashboard
      BidAnalyticsBroadcastJob.perform_later(account.id, :snapshot_update, snapshot)
      
      snapshot
    end
    
    private
    
    def calculate_avg_response_time(bid_scope)
      # Calculate average time between bid request creation and bid creation
      # This requires joining with bid_requests and calculating the difference
      avg_response_times = bid_scope.joins(:bid_request)
                                  .where.not(bid_requests: { created_at: nil })
                                  .pluck(Arel.sql("EXTRACT(EPOCH FROM bids.created_at - bid_requests.created_at)::float"))
      
      avg_response_times.any? ? (avg_response_times.sum / avg_response_times.size).round(2) : 0
    end
    
    def calculate_time_to_expiration(account, start_time, end_time)
      # Calculate average time until expiration for bid requests
      bid_requests = account.bid_requests.where(created_at: start_time..end_time)
                          .where.not(expires_at: nil)
      
      expiry_times = bid_requests.pluck(Arel.sql("EXTRACT(EPOCH FROM expires_at - created_at)::float"))
      expiry_times.any? ? (expiry_times.sum / expiry_times.size).round(2) : 0
    end
    
    def calculate_distribution_stats(bid_scope)
      # Group bids by distribution and calculate stats
      distribution_stats = {}
      
      bid_scope.group(:distribution_id).count.each do |distribution_id, count|
        next unless distribution_id
        
        distribution_bids = bid_scope.where(distribution_id: distribution_id)
        accepted_count = distribution_bids.accepted.count
        
        distribution_stats[distribution_id] = {
          total_bids: count,
          accepted_bids: accepted_count,
          acceptance_rate: count > 0 ? (accepted_count.to_f / count * 100).round(2) : 0,
          avg_amount: distribution_bids.average(:amount)&.to_f || 0
        }
      end
      
      distribution_stats
    end
    
    def calculate_campaign_stats(bid_scope)
      # Group bids by campaign and calculate stats
      campaign_stats = {}
      
      bid_scope.joins(:bid_request).group("bid_requests.campaign_id").count.each do |campaign_id, count|
        next unless campaign_id
        
        campaign_bids = bid_scope.joins(:bid_request).where(bid_requests: { campaign_id: campaign_id })
        accepted_count = campaign_bids.accepted.count
        
        campaign_stats[campaign_id] = {
          total_bids: count,
          accepted_bids: accepted_count,
          acceptance_rate: count > 0 ? (accepted_count.to_f / count * 100).round(2) : 0,
          avg_amount: campaign_bids.average(:amount)&.to_f || 0
        }
      end
      
      campaign_stats
    end
  end
end
