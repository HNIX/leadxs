# Bidding System Test Data

This directory contains seed scripts for setting up a test bidding system with distributions, campaign configurations, and simulated bid requests/bids.

## Setup Process

The main script `setup_bidding_system.rb` performs the following steps:

1. Creates test distributions with different bidding strategies (manual, rule-based, dynamic)
2. Configures ping-post campaigns with bidding settings
3. Creates test bid requests with bids from different distributions
4. Generates lead records associated with bid requests
5. Creates bid analytics snapshots for different time periods

## Usage

### Full Database Seed

The bidding setup is included in the main `db/seeds.rb` file, so running a full database seed will include the bidding system:

```bash
bin/rails db:seed
```

### Standalone Setup

You can also run just the bidding system setup using the provided rake task:

```bash
bin/rails bidding:setup      # Set up bidding system with test data
bin/rails bidding:analytics  # Generate bid analytics for the past month
bin/rails bidding:clean      # Clean up all bidding system test data
bin/rails bidding:reset      # Reset bidding system (clean and setup)
```

## Test Data Overview

The setup script creates:

- **Distributions**: 5 sample distributions with different bidding strategies and base bid amounts
- **Campaign Configurations**: Updates all ping-post campaigns with bid timeout settings and adds distributions
- **Bid Requests**: 15-30 bid requests per campaign with varying attributes
- **Bids**: 1 to N bids per bid request with different statuses and amounts
- **Leads**: Approximately 70% of bid requests have leads attached
- **Analytics**: Generates daily, weekly, and monthly analytics snapshots

## Customization

You can modify the `setup_bidding_system.rb` file to:

- Change the number of test distributions
- Adjust bidding strategies and amounts
- Modify the number of test bid requests generated
- Customize lead data generation logic
- Adjust the timeframe for historical data

## Notes

- The test data includes randomized creation dates to simulate historical activity
- Bid amounts vary based on the distribution's bidding strategy
- Bid analytics snapshots are generated for reporting and visualization
- All test data is created in the context of the "Test Account"