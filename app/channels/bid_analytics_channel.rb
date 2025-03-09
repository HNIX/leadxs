class BidAnalyticsChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_account
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end