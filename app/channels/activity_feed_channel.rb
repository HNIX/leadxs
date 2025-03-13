class ActivityFeedChannel < ApplicationCable::Channel
  def subscribed
    account_id = connection.current_user.accounts.first.id
    stream_from "activity_feed_channel_#{account_id}"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end