class Api::V1::CampaignsController < Api::BaseController
  # GET /api/v1/campaigns/:id/analytics
  # Get analytics for a specific campaign
  def analytics
    campaign = current_account.campaigns.find_by(id: params[:id])
    
    if campaign.nil?
      render json: { error: "Campaign not found" }, status: :not_found
      return
    end
    
    # Get period type or default to daily
    period_type = params[:period_type] || "daily"
    
    # Find analytics for the campaign
    analytics = current_account.bid_analytic_snapshots
      .where(campaign_id: campaign.id, period_type: period_type)
      .order(period_end: :desc)
      .limit(params[:limit] || 30)
      
    render json: {
      campaign: {
        id: campaign.id,
        name: campaign.name
      },
      analytics: analytics.map { |snapshot| snapshot_json(snapshot) }
    }
  end
  
  private
  
  def snapshot_json(snapshot)
    {
      id: snapshot.id,
      period_start: snapshot.period_start,
      period_end: snapshot.period_end,
      period_type: snapshot.period_type,
      total_bids: snapshot.total_bids,
      accepted_bids: snapshot.accepted_bids,
      rejected_bids: snapshot.rejected_bids,
      expired_bids: snapshot.expired_bids,
      avg_bid_amount: snapshot.avg_bid_amount,
      max_bid_amount: snapshot.max_bid_amount,
      min_bid_amount: snapshot.min_bid_amount,
      conversion_count: snapshot.conversion_count,
      total_revenue: snapshot.total_revenue,
      acceptance_rate: snapshot.acceptance_rate,
      conversion_rate: snapshot.conversion_rate,
      avg_revenue_per_bid: snapshot.avg_revenue_per_bid,
      avg_revenue_per_accepted_bid: snapshot.avg_revenue_per_accepted_bid,
      campaign_id: snapshot.campaign_id
    }
  end
end