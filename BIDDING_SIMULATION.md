# Bidding System Simulation Guide

This document provides guidance on how to use the simulated bidding system that has been set up in your development environment.

## Overview

The bidding system simulation creates a complete end-to-end ping-post bidding workflow including:

1. Distributions with different bidding strategies (manual, rule-based, dynamic)
2. Campaign configurations with bidding settings
3. Historical bid requests, bids, and leads
4. Bid analytics data for reporting and visualization

## Running the Simulation

### Setup the Bidding System

The easiest way to set up the bidding system is to run:

```bash
bin/rails bidding:setup
```

This will:
- Create distributions with various bidding strategies
- Configure ping-post campaigns with bidding settings
- Create sample bid requests with bids
- Generate historical analytics data

### Clean Up the Bidding Data

If you want to reset the bidding data:

```bash
bin/rails bidding:clean
```

This will remove all distributions, campaign distributions, bids, bid requests, and analytics data.

### Reset the Bidding System

To completely reset the bidding system (clean and set up again):

```bash
bin/rails bidding:reset
```

### Generate Analytics Only

If you want to generate analytics data without recreating the entire bidding setup:

```bash
bin/rails bidding:analytics
```

## Exploring the Bidding System

### Distributions (Buyers)

The simulation creates several test distributions with different bidding strategies:

1. **High Bidder Distribution**: Uses dynamic bidding with a base amount of $15.50
2. **Mid-Tier Distribution**: Uses rule-based bidding with a base amount of $10.25
3. **Budget Distribution**: Uses manual bidding with a fixed amount of $7.50
4. **Premium Distribution**: Uses dynamic bidding with a base amount of $18.75
5. **Non-Bidding Distribution**: A control distribution that doesn't participate in bidding

You can view these distributions at `/distributions` in the web interface.

### Bid Requests and Bids

The simulation creates historical bid requests and bids for all ping-post campaigns.

- Each bid request contains anonymized lead data for bidding
- Various distributions place bids with different amounts based on their bidding strategies
- Some bid requests have leads attached, simulating complete conversions

You can view bid requests at `/bid_requests` in the web interface.

### Analytics and Reporting

The simulation generates bid analytics for:

- Daily snapshots for the last 30 days
- Weekly snapshots for the last 4 weeks
- Monthly snapshots for the last 3 months

You can view the analytics dashboard at `/bid_reports` in the web interface.

## Simulating Live Bidding

To simulate live bidding, you can:

1. Create a new source in an active ping-post campaign
2. Use the source's API token to submit a lead via the API
3. Watch as the system creates a bid request and solicits bids from distributions
4. Observe the bid selection process and lead distribution

Example API call to submit a lead:

```bash
curl -X POST https://your-app-url/api/v1/leads \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_SOURCE_TOKEN" \
  -d '{
    "lead": {
      "field_name_1": "value_1",
      "field_name_2": "value_2",
      "field_name_3": "value_3"
    }
  }'
```

## Architecture

The bidding system follows this general workflow:

1. A lead is submitted via API to a ping-post campaign
2. The system creates a bid request with anonymized data
3. All eligible distributions are invited to bid
4. Distributions respond with bid amounts based on their bidding strategy
5. The winning bid is selected based on the campaign's distribution method
6. The lead is distributed to the winning distribution
7. Analytics are generated for reporting and optimization

## Technical Notes

- All test data is created within the context of the "Test Account"
- Bidding strategies include manual, rule-based, and dynamic approaches
- Bid amounts are calculated based on the distribution's bidding strategy
- Analytics data captures metrics like bid volume, amounts, response times, etc.

## Documentation

For more detailed information about the bidding system, refer to:

- `/lead_bidding_docs` in the web interface
- The bidding system source code in `db/seeds/bidding`