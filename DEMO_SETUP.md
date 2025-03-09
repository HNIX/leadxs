# LeadXS Demo System Setup Guide

This document provides comprehensive instructions for setting up a complete demo system with lead management, bidding, and analytics capabilities.

## Overview

The demo setup creates a complete end-to-end system including:

1. **User & Account**: Admin user with an account
2. **Verticals & Fields**: Industry verticals with standard fields
3. **Companies**: Publisher and buyer companies
4. **Campaigns**: Ping-post and direct campaigns
5. **Distributions**: Distribution points with different bidding strategies
6. **Sources**: Test sources for lead submissions
7. **Validation Rules**: Common validation rules for lead verification
8. **Bidding**: Complete bidding system with analytics tracking
9. **Test Data**: Sample bid requests, bids, and leads

## Setup Process

### Quick Setup (Recommended)

To set up the complete demo system, run:

```bash
bin/rails bidding:setup
```

This command will:
1. Find or create an admin user and account
2. Set up verticals, fields, campaigns, etc.
3. Configure the bidding system
4. Generate test bid requests and analytics data

### Step-by-Step Setup

If you prefer to set up components individually:

1. **Create Admin User & Account**:
   This happens automatically when running `bidding:setup`

2. **Set Up Verticals & Fields**:
   ```bash
   bin/rails console
   admin_account = User.find_by(email: "admin@example.com").accounts.first
   ActsAsTenant.with_tenant(admin_account) do
     Seeds::Bidding::SetupCompleteSystem.setup_verticals(admin_account)
   end
   ```

3. **Set Up Companies**:
   ```bash
   ActsAsTenant.with_tenant(admin_account) do
     Seeds::Bidding::SetupCompleteSystem.setup_companies(admin_account)
   end
   ```

4. **Set Up Campaigns**:
   ```bash
   ActsAsTenant.with_tenant(admin_account) do
     Seeds::Bidding::SetupCompleteSystem.setup_campaigns(admin_account)
   end
   ```

5. **Add Distributions**:
   ```bash
   ActsAsTenant.with_tenant(admin_account) do
     Seeds::Bidding::SetupBiddingSystem.create_distributions(admin_account)
   end
   ```

6. **Connect Campaigns & Distributions**:
   ```bash
   ActsAsTenant.with_tenant(admin_account) do
     Seeds::Bidding::SetupCompleteSystem.add_distributions_to_campaigns(admin_account)
   end
   ```

7. **Generate Test Data**:
   ```bash
   ActsAsTenant.with_tenant(admin_account) do
     Seeds::Bidding::SetupBiddingSystem.create_test_bid_requests(admin_account)
   end
   ```

8. **Generate Analytics**:
   ```bash
   ActsAsTenant.with_tenant(admin_account) do
     Seeds::Bidding::SetupBiddingSystem.generate_analytics(admin_account)
   end
   ```

## Maintenance Tasks

### Generate Additional Analytics

If you want to generate more analytics data:

```bash
bin/rails bidding:analytics
```

### Clean Up Demo Data

To remove all demo data:

```bash
bin/rails bidding:clean
```

### Reset Demo System

To completely reset the demo system (clean and set up again):

```bash
bin/rails bidding:reset
```

## Exploring the Demo System

After setup, you can explore the system through the web interface:

- **Login**: Use email `admin@example.com` with password `password`

### Key Areas to Explore

1. **Verticals**: `/verticals` - View industry verticals and their fields
2. **Campaigns**: `/campaigns` - Explore ping-post and direct campaigns
3. **Distributions**: `/distributions` - View distribution points and bidding strategies
4. **Bid Requests**: `/bid_requests` - See bid requests and their bids
5. **Analytics**: `/bid_reports` - Explore bid performance metrics
6. **Documentation**: `/lead_bidding_docs` - Read system documentation

## Creating Test Leads

To simulate a new lead submission:

1. Find a source token from any ping-post campaign source
2. Submit a lead via the API:

```bash
curl -X POST http://localhost:3000/api/v1/leads \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_SOURCE_TOKEN" \
  -d '{
    "lead": {
      "first_name": "John",
      "last_name": "Doe",
      "email": "john.doe@example.com",
      "phone": "5551234567",
      "city": "Seattle",
      "state": "WA",
      "zip": "98101"
      # Add additional fields based on the campaign
    }
  }'
```

3. Watch as a bid request is created and bids are solicited
4. View the results in the bid requests dashboard

## System Structure

### Verticals

The system includes common industry verticals:
- Auto Insurance
- Home Insurance
- Personal Loans
- Home Services

Each vertical has specialized fields relevant to its industry.

### Campaigns

Two types of campaigns are created for each vertical:
- **Ping-Post Campaigns**: Support bidding and lead distribution
- **Direct Campaigns**: Traditional direct lead routing

### Bidding System

The bidding system includes:
- **Distributions**: Four distribution types with different bidding strategies
- **Bid Requests**: Test bid requests with varying attributes
- **Bids**: Sample bids with different amounts and statuses
- **Analytics**: Performance metrics and reporting

## Technical Notes

- All demo data is created within the admin user's account
- Bidding strategies include manual, rule-based, and dynamic approaches
- The system generates analytics at hourly, daily, weekly, and monthly intervals
- All components are properly connected with appropriate relationships

## Troubleshooting

If you encounter issues:

1. **Database Errors**: Try running `bin/rails db:reset` followed by `bin/rails bidding:setup`
2. **Missing Relations**: Check if all migrations have been run with `bin/rails db:migrate:status`
3. **Account Issues**: Verify the admin account exists with `User.where(email: "admin@example.com")`
4. **Tenant Issues**: Make sure ActsAsTenant is working correctly