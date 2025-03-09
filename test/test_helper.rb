ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require "webmock/minitest"
require_relative "fixtures/bid_analytic_snapshots"

# Uncomment to view full stack trace in tests
# Rails.backtrace_cleaner.remove_silencers!

if defined?(Sidekiq)
  require "sidekiq/testing"
  Sidekiq.logger.level = Logger::WARN
end

if defined?(SolidQueue)
  SolidQueue.logger.level = Logger::WARN
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    def json_response
      JSON.decode(response.body)
    end
    
    # Helper method for creating test BidAnalyticSnapshot objects with valid metrics
    def create_bid_analytic_snapshot(attributes = {})
      default_metrics = {
        bid_requests_sent: attributes[:total_bids] || 100,
        avg_response_time: 2.5,
        time_to_expiration: 30.0,
        distribution_stats: {},
        campaign_stats: {}
      }
      
      BidAnalyticSnapshot.create!({
        account: accounts(:one),
        period_start: 1.day.ago,
        period_end: Time.current,
        period_type: :daily,
        total_bids: 100,
        accepted_bids: 75,
        rejected_bids: 20,
        expired_bids: 5,
        avg_bid_amount: 35.0,
        max_bid_amount: 50.0,
        min_bid_amount: 20.0,
        conversion_count: 50,
        total_revenue: 1750.0,
        metrics: default_metrics
      }.merge(attributes))
    end
  end
end

module ActionDispatch
  class IntegrationTest
    include Devise::Test::IntegrationHelpers

    def switch_account(account)
      patch "/accounts/#{account.id}/switch"
    end
  end
end

WebMock.disable_net_connect!({
  allow_localhost: true,
  allow: [
    "chromedriver.storage.googleapis.com",
    "rails-app",
    "selenium"
  ]
})
