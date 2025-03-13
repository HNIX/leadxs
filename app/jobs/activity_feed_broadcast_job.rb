class ActivityFeedBroadcastJob < ApplicationJob
  queue_as :default
  include LeadActivitiesHelper
  include ActionView::Helpers::DateHelper
  include ActionView::Helpers::NumberHelper

  def perform(record, type)
    return unless record&.account_id

    case type
    when :activity
      broadcast_activity(record)
    when :lead
      broadcast_lead(record)
    when :bid
      broadcast_bid(record)
    when :distribution
      broadcast_distribution(record)
    end
  end

  private

  def broadcast_activity(activity)
    html = ApplicationController.render(
      partial: 'lead_activities/activity',
      locals: { activity: activity, compact: false }
    )

    ActionCable.server.broadcast(
      "activity_feed_channel_#{activity.account_id}",
      { type: 'activity', html: html }
    )
  end

  def broadcast_lead(lead)
    # Use a partial instead of inline ERB to ensure helper methods are available
    html = ApplicationController.render(
      partial: 'activity_feed/lead',
      locals: { lead: lead }
    )

    ActionCable.server.broadcast(
      "activity_feed_channel_#{lead.account_id}",
      { type: 'lead', html: html }
    )
  end

  def broadcast_bid(bid)
    # Use a partial instead of inline ERB to ensure helper methods are available
    html = ApplicationController.render(
      partial: 'activity_feed/bid',
      locals: { bid: bid }
    )

    ActionCable.server.broadcast(
      "activity_feed_channel_#{bid.account_id}",
      { type: 'bid', html: html }
    )
  end

  def broadcast_distribution(campaign_distribution)
    # Use a partial instead of inline ERB to ensure helper methods are available
    html = ApplicationController.render(
      partial: 'activity_feed/distribution',
      locals: { campaign_distribution: campaign_distribution }
    )

    ActionCable.server.broadcast(
      "activity_feed_channel_#{campaign_distribution.account_id}",
      { type: 'distribution', html: html }
    )
  end
end