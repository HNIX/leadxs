# Lead Exchange System - Model Relationships

## Overview

The Swayed LDX (Lead Exchange) system is a comprehensive platform for lead generation, distribution, and management. It provides a regulatory-compliant framework for handling leads through a bidding system and distribution workflow that ensures proper consent and data handling.

The core domain models can be grouped into several major components:

1. **User Management**: Account, User, AccountUser for multi-tenancy
2. **Vertical System**: Verticals, VerticalFields, StandardFields for defining data structures
3. **Campaign System**: Campaigns, CampaignFields for campaign configuration
4. **Source Integration**: Sources and related entities for lead intake
5. **Distribution System**: Distributions, MappedFields for sending leads to buyers
6. **Bidding System**: BidRequests, Bids for facilitating lead auctions
7. **Compliance Framework**: ComplianceRecords, ConsentRecords for regulatory adherence

## Core Domain Models

### Account System

#### Account
**Purpose:** Central tenant model for multi-tenancy architecture.  
**Key Attributes:** name, personal, billing_email, domain  
**Relationships:**
- `belongs_to :owner` (User)
- `has_many :account_invitations`
- `has_many :account_users`
- `has_many :users` (through account_users)
- `has_many :companies`
- `has_many :verticals`
- `has_many :campaigns`
- `has_many :sources`
- `has_many :api_requests`
- `has_many :distributions`
- `has_many :validation_rules`
- `has_many :bid_requests`
- `has_many :bids`
- `has_many :bid_analytic_snapshots`
- `has_many :standard_fields`
- `has_many :compliance_records`
- `has_many :consent_records`
- `has_many :data_access_records`

**Function:** Serves as the tenant container for all account-specific data, enabling multi-tenancy through the acts_as_tenant gem. Each account can be personal (for a specific user) or a team account shared among multiple users.

#### User
**Purpose:** Represents system users with authentication and authorization.  
**Key Attributes:** email, name, time_zone, preferred_language  
**Relationships:**
- `has_many :account_users`
- `has_many :accounts` (through account_users)
- `has_many :owned_accounts` (inverse of owner on Account)
- `has_many :notification_tokens`
- `has_many :connected_accounts`

**Function:** Manages user identity, authentication, and access to accounts. Users can belong to multiple accounts with different roles.

#### AccountUser
**Purpose:** Join model between User and Account models.  
**Key Attributes:** role  
**Relationships:**
- `belongs_to :account`
- `belongs_to :user`

**Function:** Establishes the relationship between users and accounts, specifying the role (admin, member, etc.) a user has within an account.

### Vertical System

#### Vertical
**Purpose:** Defines an industry vertical or lead category.  
**Key Attributes:** name, primary_category, secondary_category, archived, base  
**Relationships:**
- `acts_as_tenant :account`
- `has_many :campaigns`
- `has_many :vertical_fields`
- `has_many :validation_rules` (polymorphic)

**Function:** Organizes leads and campaigns by industry category, allowing for standardized field definitions and validation rules that make sense for a specific vertical.

#### VerticalField
**Purpose:** Defines field templates for a vertical.  
**Key Attributes:** name, label, data_type, value_acceptance, required, is_pii  
**Relationships:**
- `acts_as_tenant :account`
- `belongs_to :vertical`
- `has_many :campaign_fields`
- `has_many :list_values` (polymorphic as list_owner)
- `has_rich_text :notes`

**Function:** Serves as a template for fields within a vertical, defining their data types, validation rules, and requirements. These fields can be automatically applied to new campaigns within the vertical.

#### StandardField
**Purpose:** Global field definitions that can be applied across verticals.  
**Key Attributes:** name, label, data_type, value_acceptance, required, is_pii  
**Relationships:**
- `acts_as_tenant :account`
- `belongs_to :account`
- `has_many :list_values` (polymorphic as list_owner)
- `has_rich_text :notes`

**Function:** Provides standardized field definitions that can be automatically applied to any vertical, ensuring consistency across the platform. Standard fields represent common data points used across multiple verticals.

### Campaign System

#### Campaign
**Purpose:** Defines a lead generation campaign.  
**Key Attributes:** name, status, campaign_type, distribution_method, bid_timeout_seconds  
**Relationships:**
- `acts_as_tenant :account`
- `belongs_to :vertical`
- `has_many :campaign_fields`
- `has_many :calculated_fields`
- `has_many :validation_rules` (polymorphic as validatable)
- `has_many :sources`
- `has_many :campaign_distributions`
- `has_many :distributions` (through campaign_distributions)
- `has_many :leads`
- `has_many :source_filters`
- `has_many :distribution_filters`
- `has_many :bid_requests`
- `has_many :bid_analytic_snapshots`
- `has_many :form_builders`

**Function:** The central entity for lead generation, defining how leads are collected, validated, and distributed. Campaigns are associated with a vertical and can have different distribution methods, including bidding systems.

#### CampaignField
**Purpose:** Defines specific fields for a campaign.  
**Key Attributes:** name, label, data_type, required, field_type, position  
**Relationships:**
- `acts_as_tenant :account`
- `belongs_to :campaign`
- `belongs_to :vertical_field` (optional)
- `has_many :list_values` (polymorphic as list_owner)
- `has_rich_text :notes`

**Function:** Defines the specific fields that are collected for a campaign. These can be derived from vertical fields but may have campaign-specific validation rules or requirements. Campaign fields track what data is collected for each lead.

#### CalculatedField
**Purpose:** Dynamic fields calculated from other campaign fields.  
**Key Attributes:** name, formula, field_type  
**Relationships:**
- `belongs_to :campaign`

**Function:** Allows for derived fields that calculate values based on other fields in a campaign, using defined formulas to transform or combine data.

#### ValidationRule
**Purpose:** Defines data validation rules for leads.  
**Key Attributes:** name, rule_type, condition, error_message, severity  
**Relationships:**
- `acts_as_tenant :account`
- `belongs_to :validatable` (polymorphic to Campaign or Vertical)

**Function:** Ensures data quality and compliance by defining rules that validate lead data. Rules can be simple pattern matching, complex conditions, or cross-field validations.

### Lead Management

#### Lead
**Purpose:** Represents a generated lead with associated data.  
**Key Attributes:** unique_id, status, error_message  
**Relationships:**
- `acts_as_tenant :account`
- `belongs_to :campaign`
- `belongs_to :source` (optional)
- `belongs_to :bid_request` (optional)
- `has_many :lead_activity_logs`
- `has_many :lead_data`
- `has_many :api_requests`
- `has_one :generated_bid_request`
- `has_many :consent_records`
- `has_many :compliance_records` (polymorphic as record)
- `has_many :data_access_records` (polymorphic as record)

**Function:** The core entity representing a lead in the system. Contains all data associated with a lead, tracks its status through the distribution process, and maintains compliance records.

#### LeadData
**Purpose:** Stores individual field values for a lead.  
**Key Attributes:** value, campaign_field_id  
**Relationships:**
- `belongs_to :lead`
- `belongs_to :campaign_field`

**Function:** Stores the actual field values for a lead in a flexible, extensible structure. Each LeadData entry represents one field value for a lead.

#### LeadActivityLog
**Purpose:** Tracks actions and events related to leads.  
**Key Attributes:** activity_type, details, status, performed_by_type, performed_by_id  
**Relationships:**
- `belongs_to :lead`

**Function:** Provides an audit trail of all activities related to a lead, such as creation, validation, distribution, and access events.

### Source System

#### Source
**Purpose:** Defines a lead source integration.  
**Key Attributes:** name, integration_type, token, status  
**Relationships:**
- `acts_as_tenant :account`
- `belongs_to :campaign`
- `belongs_to :company`
- `belongs_to :form_builder` (optional)
- `has_many :leads`

**Function:** Represents an entity that provides leads to the system, such as an affiliate, web form, or form builder. Sources are associated with campaigns and have authentication tokens for API access.

#### Company
**Purpose:** Represents an organization in the system.  
**Key Attributes:** name, status, company_type, industry  
**Relationships:**
- `acts_as_tenant :account`
- `has_many :contacts`
- `has_many :sources`
- `has_many :distributions`

**Function:** Provides organizational context for sources and distributions, representing either lead providers (publishers) or lead buyers.

#### Contact
**Purpose:** Represents a contact person at a company.  
**Key Attributes:** name, email, phone, role  
**Relationships:**
- `acts_as_tenant :account`
- `belongs_to :company`

**Function:** Stores contact information for individuals associated with companies, enabling communication with publishers and buyers.

### Distribution System

#### Distribution
**Purpose:** Defines an endpoint for distributing leads.  
**Key Attributes:** name, endpoint_url, request_method, request_format, status  
**Relationships:**
- `acts_as_tenant :account`
- `belongs_to :company`
- `has_many :campaign_distributions`
- `has_many :campaigns` (through campaign_distributions)
- `has_many :headers`
- `has_many :api_requests` (polymorphic as requestable)
- `has_many :leads` (through api_requests)
- `has_many :bids`
- `has_many :bid_analytic_snapshots`

**Function:** Configures how leads are sent to buyers, including the endpoint, request format, and authentication details. Distributions participate in the bidding process for ping-post campaigns.

#### CampaignDistribution
**Purpose:** Join model between Campaign and Distribution.  
**Key Attributes:** active, priority  
**Relationships:**
- `belongs_to :campaign`
- `belongs_to :distribution`
- `has_many :mapped_fields`

**Function:** Associates distributions with campaigns, defining priorities and enabling configuration of field mappings specific to each campaign-distribution pair.

#### MappedField
**Purpose:** Maps campaign fields to distribution fields.  
**Key Attributes:** campaign_field_id, target_field, template  
**Relationships:**
- `belongs_to :campaign_distribution`

**Function:** Configures how campaign fields are mapped to the fields expected by a distribution endpoint, allowing for field name translation and value transformation.

#### Header
**Purpose:** Defines HTTP headers for distribution requests.  
**Key Attributes:** name, value  
**Relationships:**
- `belongs_to :distribution`

**Function:** Configures HTTP headers to send with API requests to distribution endpoints, often used for authentication or content negotiation.

### Bidding System

#### BidRequest
**Purpose:** Initiates a bidding process for a lead.  
**Key Attributes:** unique_id, status, anonymized_data, expires_at  
**Relationships:**
- `acts_as_tenant :account`
- `belongs_to :campaign`
- `belongs_to :lead` (optional)
- `has_many :bids`

**Function:** Represents a request for bids on a lead, containing anonymized lead data that buyers can use to make bidding decisions. Manages the bidding process lifecycle.

#### Bid
**Purpose:** Represents a buyer's bid on a lead.  
**Key Attributes:** amount, status  
**Relationships:**
- `acts_as_tenant :account`
- `belongs_to :bid_request`
- `belongs_to :distribution`
- `has_one :api_request` (polymorphic as requestable)

**Function:** Records a buyer's bid amount and status in response to a bid request. The highest bid typically wins the right to receive the full lead data.

#### BidAnalyticSnapshot
**Purpose:** Stores analytical data about bidding activity.  
**Key Attributes:** metrics, period_type, start_date, end_date  
**Relationships:**
- `acts_as_tenant :account`
- `belongs_to :campaign` (optional)
- `belongs_to :distribution` (optional)

**Function:** Provides aggregated metrics about bidding activity, enabling analysis of bidding patterns, win rates, and revenue performance.

### Compliance Framework

#### ComplianceRecord
**Purpose:** Records compliance events for regulatory purposes.  
**Key Attributes:** event_type, action, occurred_at, data  
**Relationships:**
- `acts_as_tenant :account`
- `belongs_to :record` (polymorphic)
- `belongs_to :user` (optional)

**Function:** Creates an immutable audit trail of compliance-related events, such as consent verification, data access, or regulatory notifications.

#### ConsentRecord
**Purpose:** Records explicit consent given by a lead.  
**Key Attributes:** consent_type, consent_text, consented_at, expires_at, revoked_at  
**Relationships:**
- `acts_as_tenant :account`
- `belongs_to :lead`

**Function:** Documents when and how a lead provided explicit consent, ensuring regulatory compliance with privacy laws like TCPA or GDPR.

#### DataAccessRecord
**Purpose:** Tracks who accessed lead data and why.  
**Key Attributes:** action, purpose, accessed_at  
**Relationships:**
- `acts_as_tenant :account`
- `belongs_to :record` (polymorphic)
- `belongs_to :user`

**Function:** Creates an audit trail of data access events for compliance purposes, recording who accessed data, when, and for what purpose.

### API and Integration

#### ApiRequest
**Purpose:** Records API interactions with external systems.  
**Key Attributes:** endpoint_url, request_method, request_data, response_data, response_code  
**Relationships:**
- `acts_as_tenant :account`
- `belongs_to :requestable` (polymorphic)
- `belongs_to :lead` (optional)

**Function:** Logs all API requests and responses for debugging, auditing, and compliance purposes. Associated with leads and distribution or bid endpoints.

#### ApiToken
**Purpose:** Manages API authentication tokens.  
**Key Attributes:** name, token, expires_at  
**Relationships:**
- `belongs_to :user`

**Function:** Enables secure API access by providing authentication tokens, with tracking of token usage and expiration.

## Other Supporting Models

### Filter System

#### Filter (SourceFilter/DistributionFilter)
**Purpose:** Defines filtering criteria for lead routing.  
**Key Attributes:** name, filter_type, condition, parameters  
**Relationships:**
- `belongs_to :campaign`

**Function:** Determines which sources can submit leads or which distributions can receive leads based on configured conditions and parameters.

### Form Builder System

#### FormBuilder
**Purpose:** Defines a form to collect lead data.  
**Key Attributes:** name, status, form_type  
**Relationships:**
- `belongs_to :campaign`
- `has_many :form_builder_elements`
- `has_many :form_builder_analytics`
- `has_many :sources`

**Function:** Provides a form-building interface that generates web forms for collecting lead data directly through the platform.

#### FormSubmission
**Purpose:** Records a submission through a form builder.  
**Key Attributes:** form_data, status  
**Relationships:**
- `belongs_to :form_builder`
- `has_one :lead`

**Function:** Captures form submissions and initiates lead creation and processing workflows.

### Notification System

#### NotificationToken
**Purpose:** Manages push notification tokens.  
**Key Attributes:** token, platform, enabled  
**Relationships:**
- `belongs_to :user`

**Function:** Stores tokens for sending push notifications to mobile devices or browsers.

### Miscellaneous

#### ListValue
**Purpose:** Stores option values for field lists.  
**Key Attributes:** list_value, value_type, position  
**Relationships:**
- `belongs_to :list_owner` (polymorphic)

**Function:** Provides predefined values for fields with list-based acceptance criteria, such as dropdowns or radio options.

#### Announcement
**Purpose:** System-wide announcements and notifications.  
**Key Attributes:** title, description, published_at  
**Relationships:**
- No significant relationships outside of basic ApplicationRecord

**Function:** Enables platform administrators to communicate updates, changes, or important information to users.

## Workflow Interactions

The Lead Exchange System follows several key workflows:

1. **Lead Collection**: Sources submit leads to campaigns, either through direct API integration, web forms, or the form builder system.

2. **Lead Validation**: When leads are received, they are validated against campaign field requirements and validation rules to ensure data quality and compliance.

3. **Bidding Process** (for ping-post campaigns):
   - A BidRequest is created with anonymized lead data
   - Eligible distributions submit Bids
   - The winning bid is determined based on campaign distribution method
   - The lead is then distributed to the winning bidder

4. **Direct Distribution** (for direct campaigns):
   - Leads are validated and then immediately distributed to configured endpoints
   - Field mapping ensures the lead data matches the format expected by the distribution

5. **Compliance Tracking**: Throughout the process, compliance records, consent records, and data access records are created to maintain an audit trail for regulatory purposes.

This architecture enables a flexible, compliant lead exchange system that supports both traditional direct lead distribution and modern ping-post bidding workflows, with robust tracking for compliance and analytics purposes.