class BidAnalyticsBroadcastJob < ApplicationJob
  queue_as :default

  def perform(account_id, update_type, data)
    account = Account.find_by(id: account_id)
    return unless account

    # Broadcast to the channel for this account
    case update_type
    when :snapshot_update
      BidAnalyticsChannel.broadcast_to(
        account,
        {
          type: 'snapshot_update',
          metrics: prepare_metrics_data(data)
        }
      )
    when :new_bid
      BidAnalyticsChannel.broadcast_to(
        account,
        {
          type: 'new_bid',
          bid: prepare_bid_data(data)
        }
      )
    end
  end

  private

  def prepare_metrics_data(snapshot)
    {
      total_bids: snapshot.total_bids,
      accepted_bids: snapshot.accepted_bids,
      rejected_bids: snapshot.rejected_bids,
      expired_bids: snapshot.expired_bids,
      avg_bid_amount: snapshot.avg_bid_amount.to_f.round(2),
      max_bid_amount: snapshot.max_bid_amount.to_f.round(2),
      min_bid_amount: snapshot.min_bid_amount.to_f.round(2),
      conversion_count: snapshot.conversion_count,
      total_revenue: snapshot.total_revenue.to_f.round(2),
      acceptance_rate: ((snapshot.accepted_bids.to_f / snapshot.total_bids) * 100).round(2),
      conversion_rate: ((snapshot.conversion_count.to_f / snapshot.total_bids) * 100).round(2),
      revenue_per_bid: (snapshot.total_revenue.to_f / snapshot.total_bids).round(2),
      revenue_per_accepted_bid: (snapshot.total_revenue.to_f / snapshot.accepted_bids).round(2),
      bidVolumes: prepare_time_series(snapshot.account, :total_bids),
      conversionRates: prepare_time_series(snapshot.account, :conversion_rate),
      period_start: snapshot.period_start.strftime('%Y-%m-%d %H:%M')
    }
  end

  def prepare_bid_data(bid)
    {
      id: bid.id,
      amount: bid.amount.to_f,
      status: bid.status,
      campaign: bid.campaign.name,
      distribution: bid.distribution&.name || 'N/A',
      created_at: bid.created_at.strftime('%Y-%m-%d %H:%M:%S')
    }
  end
  
  def prepare_time_series(account, metric)
    snapshots = BidAnalyticSnapshot.hourly.last(24) || []
    snapshots.map do |s|
      value = if metric == :conversion_rate
                s.conversion_count.to_f / (s.total_bids.nonzero? || 1) * 100
              else
                s.send(metric).to_f
              end
      
      {
        timestamp: s.period_start.to_i * 1000,
        value: value.round(2)
      }
    end
  end
end