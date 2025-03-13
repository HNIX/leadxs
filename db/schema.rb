# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_03_13_020922) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "account_invitations", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "invited_by_id"
    t.string "token", null: false
    t.string "name", null: false
    t.string "email", null: false
    t.jsonb "roles", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "email"], name: "index_account_invitations_on_account_id_and_email", unique: true
    t.index ["invited_by_id"], name: "index_account_invitations_on_invited_by_id"
    t.index ["token"], name: "index_account_invitations_on_token", unique: true
  end

  create_table "account_users", force: :cascade do |t|
    t.bigint "account_id"
    t.bigint "user_id"
    t.jsonb "roles", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "user_id"], name: "index_account_users_on_account_id_and_user_id", unique: true
  end

  create_table "accounts", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "owner_id"
    t.boolean "personal", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "extra_billing_info"
    t.string "domain"
    t.string "subdomain"
    t.string "billing_email"
    t.integer "account_users_count", default: 0
    t.index ["owner_id"], name: "index_accounts_on_owner_id"
  end

  create_table "action_text_embeds", force: :cascade do |t|
    t.string "url"
    t.jsonb "fields"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", precision: nil, null: false
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "addresses", force: :cascade do |t|
    t.string "addressable_type", null: false
    t.bigint "addressable_id", null: false
    t.integer "address_type"
    t.string "line1"
    t.string "line2"
    t.string "city"
    t.string "state"
    t.string "country"
    t.string "postal_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["addressable_type", "addressable_id"], name: "index_addresses_on_addressable"
  end

  create_table "announcements", force: :cascade do |t|
    t.string "kind"
    t.string "title"
    t.datetime "published_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "api_requests", force: :cascade do |t|
    t.string "requestable_type", null: false
    t.bigint "requestable_id", null: false
    t.bigint "lead_id"
    t.string "endpoint_url", null: false
    t.integer "request_method", null: false
    t.text "request_payload"
    t.integer "response_code"
    t.text "response_payload"
    t.integer "duration_ms"
    t.text "error"
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "account_id", null: false
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.index ["account_id"], name: "index_api_requests_on_account_id"
    t.index ["requestable_type", "requestable_id", "created_at"], name: "idx_on_requestable_type_requestable_id_created_at_3b74dff40b"
    t.index ["requestable_type", "requestable_id"], name: "index_api_requests_on_requestable"
    t.index ["uuid"], name: "index_api_requests_on_uuid", unique: true
  end

  create_table "api_tokens", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token"
    t.string "name"
    t.jsonb "metadata", default: {}
    t.boolean "transient", default: false
    t.datetime "last_used_at", precision: nil
    t.datetime "expires_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token"], name: "index_api_tokens_on_token", unique: true
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
  end

  create_table "bid_analytic_snapshots", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "period_start", null: false
    t.datetime "period_end", null: false
    t.string "period_type", null: false
    t.jsonb "metrics", default: "{}", null: false
    t.integer "total_bids", default: 0, null: false
    t.integer "accepted_bids", default: 0, null: false
    t.integer "rejected_bids", default: 0, null: false
    t.integer "expired_bids", default: 0, null: false
    t.decimal "avg_bid_amount", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "max_bid_amount", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "min_bid_amount", precision: 10, scale: 2, default: "0.0", null: false
    t.integer "conversion_count", default: 0, null: false
    t.decimal "total_revenue", precision: 10, scale: 2, default: "0.0", null: false
    t.bigint "campaign_id"
    t.bigint "distribution_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "campaign_id"], name: "index_bid_analytic_snapshots_on_account_id_and_campaign_id", where: "(campaign_id IS NOT NULL)"
    t.index ["account_id", "distribution_id"], name: "index_bid_analytic_snapshots_on_account_id_and_distribution_id", where: "(distribution_id IS NOT NULL)"
    t.index ["account_id", "period_type", "period_start", "period_end"], name: "idx_on_account_id_period_type_period_start_period_e_f54a4ef7dd"
    t.index ["account_id"], name: "index_bid_analytic_snapshots_on_account_id"
    t.index ["campaign_id"], name: "index_bid_analytic_snapshots_on_campaign_id"
    t.index ["distribution_id"], name: "index_bid_analytic_snapshots_on_distribution_id"
  end

  create_table "bid_requests", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "campaign_id", null: false
    t.bigint "lead_id"
    t.string "unique_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "expires_at", null: false
    t.jsonb "anonymized_data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "bid_metadata", default: {}
    t.datetime "completed_at"
    t.index ["account_id", "unique_id"], name: "index_bid_requests_on_account_id_and_unique_id", unique: true
    t.index ["account_id"], name: "index_bid_requests_on_account_id"
    t.index ["bid_metadata"], name: "index_bid_requests_on_bid_metadata", using: :gin
    t.index ["campaign_id"], name: "index_bid_requests_on_campaign_id"
    t.index ["expires_at"], name: "index_bid_requests_on_expires_at"
    t.index ["lead_id"], name: "index_bid_requests_on_lead_id"
    t.index ["status"], name: "index_bid_requests_on_status"
    t.index ["unique_id"], name: "index_bid_requests_on_unique_id", unique: true
  end

  create_table "bids", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "bid_request_id", null: false
    t.bigint "distribution_id", null: false
    t.decimal "amount", precision: 10, scale: 2, default: "0.0", null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "status"], name: "index_bids_on_account_id_and_status"
    t.index ["account_id"], name: "index_bids_on_account_id"
    t.index ["amount"], name: "index_bids_on_amount"
    t.index ["bid_request_id", "distribution_id"], name: "index_bids_on_bid_request_id_and_distribution_id", unique: true
    t.index ["bid_request_id"], name: "index_bids_on_bid_request_id"
    t.index ["distribution_id"], name: "index_bids_on_distribution_id"
  end

  create_table "calculated_fields", force: :cascade do |t|
    t.bigint "campaign_id", null: false
    t.bigint "account_id", null: false
    t.string "name", null: false
    t.text "formula"
    t.text "clean_formula"
    t.string "status", default: "active"
    t.jsonb "error_log", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "share_during_bidding", default: false
    t.index ["account_id"], name: "index_calculated_fields_on_account_id"
    t.index ["campaign_id", "name"], name: "index_calculated_fields_on_campaign_id_and_name", unique: true
    t.index ["campaign_id"], name: "index_calculated_fields_on_campaign_id"
    t.index ["share_during_bidding"], name: "index_calculated_fields_on_share_during_bidding"
  end

  create_table "campaign_distributions", force: :cascade do |t|
    t.bigint "campaign_id", null: false
    t.bigint "distribution_id", null: false
    t.boolean "active", default: true, null: false
    t.integer "priority", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_used_at"
    t.bigint "account_id", null: false
    t.index ["account_id"], name: "index_campaign_distributions_on_account_id"
    t.index ["campaign_id", "distribution_id"], name: "idx_on_campaign_id_distribution_id_81ffb0256c", unique: true
    t.index ["campaign_id"], name: "index_campaign_distributions_on_campaign_id"
    t.index ["distribution_id"], name: "index_campaign_distributions_on_distribution_id"
  end

  create_table "campaign_fields", force: :cascade do |t|
    t.string "name"
    t.string "field_type"
    t.boolean "required"
    t.string "default_value"
    t.text "description"
    t.string "validation_regex"
    t.integer "min_length"
    t.integer "max_length"
    t.float "min_value"
    t.float "max_value"
    t.text "options"
    t.integer "position"
    t.bigint "campaign_id", null: false
    t.bigint "vertical_field_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "label"
    t.integer "data_type"
    t.boolean "is_pii", default: false
    t.boolean "ping_required", default: false
    t.boolean "post_required", default: false
    t.boolean "post_only", default: false
    t.boolean "hide", default: false
    t.string "example_value"
    t.integer "value_acceptance", default: 0
    t.bigint "account_id", null: false
    t.boolean "share_during_bidding", default: false
    t.index ["account_id", "campaign_id", "name"], name: "index_campaign_fields_on_account_campaign_and_name"
    t.index ["account_id"], name: "index_campaign_fields_on_account_id"
    t.index ["campaign_id", "position"], name: "index_campaign_fields_on_campaign_id_and_position"
    t.index ["campaign_id"], name: "index_campaign_fields_on_campaign_id"
    t.index ["share_during_bidding"], name: "index_campaign_fields_on_share_during_bidding"
    t.index ["vertical_field_id"], name: "index_campaign_fields_on_vertical_field_id"
  end

  create_table "campaigns", force: :cascade do |t|
    t.string "name"
    t.string "status"
    t.string "campaign_type"
    t.text "description"
    t.string "distribution_method"
    t.boolean "distribution_schedule_enabled"
    t.string "distribution_schedule_days"
    t.time "distribution_schedule_start_time"
    t.time "distribution_schedule_end_time"
    t.bigint "vertical_id", null: false
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "bid_timeout_seconds", default: 5
    t.decimal "minimum_bid_amount", precision: 10, scale: 2
    t.string "multi_distribution_strategy", default: "sequential"
    t.integer "max_distributions", default: 1
    t.index ["account_id"], name: "index_campaigns_on_account_id"
    t.index ["multi_distribution_strategy"], name: "index_campaigns_on_multi_distribution_strategy"
    t.index ["vertical_id"], name: "index_campaigns_on_vertical_id"
  end

  create_table "companies", force: :cascade do |t|
    t.string "name"
    t.string "address"
    t.string "city"
    t.string "state"
    t.string "zip_code"
    t.string "billing_cycle"
    t.string "payment_terms"
    t.string "currency"
    t.string "tax_id"
    t.text "notes"
    t.string "status", default: "active"
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "name"], name: "index_companies_on_account_id_and_name"
    t.index ["account_id"], name: "index_companies_on_account_id"
  end

  create_table "compliance_records", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.string "action", null: false
    t.string "event_type", null: false
    t.jsonb "data", default: {}
    t.bigint "user_id"
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "occurred_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "event_type"], name: "index_compliance_records_on_account_id_and_event_type"
    t.index ["account_id"], name: "index_compliance_records_on_account_id"
    t.index ["occurred_at"], name: "index_compliance_records_on_occurred_at"
    t.index ["record_type", "record_id"], name: "index_compliance_records_on_record_type_and_record_id"
  end

  create_table "connected_accounts", force: :cascade do |t|
    t.bigint "owner_id"
    t.string "provider"
    t.string "uid"
    t.string "refresh_token"
    t.datetime "expires_at", precision: nil
    t.jsonb "auth"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "access_token"
    t.string "access_token_secret"
    t.string "owner_type"
    t.index ["owner_id", "owner_type"], name: "index_connected_accounts_on_owner_id_and_owner_type"
  end

  create_table "consent_records", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "lead_id", null: false
    t.bigint "user_id"
    t.string "consent_type", null: false
    t.text "consent_text", null: false
    t.string "ip_address", null: false
    t.string "user_agent"
    t.datetime "consented_at", null: false
    t.datetime "expires_at"
    t.string "proof_token"
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.jsonb "metadata", default: {}
    t.boolean "revoked", default: false
    t.datetime "revoked_at"
    t.text "revocation_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_consent_records_on_account_id"
    t.index ["consented_at"], name: "index_consent_records_on_consented_at"
    t.index ["lead_id", "consent_type"], name: "index_consent_records_on_lead_id_and_consent_type"
    t.index ["lead_id"], name: "index_consent_records_on_lead_id"
    t.index ["proof_token"], name: "index_consent_records_on_proof_token"
    t.index ["revoked"], name: "index_consent_records_on_revoked"
    t.index ["uuid"], name: "index_consent_records_on_uuid", unique: true
  end

  create_table "contacts", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "email"
    t.string "phone"
    t.bigint "company_id", null: false
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "email"], name: "index_contacts_on_account_id_and_email"
    t.index ["account_id"], name: "index_contacts_on_account_id"
    t.index ["company_id"], name: "index_contacts_on_company_id"
  end

  create_table "data_access_records", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "user_id", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.string "action", null: false
    t.string "purpose"
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "accessed_at", null: false
    t.jsonb "fields_accessed", default: []
    t.string "access_context"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "accessed_at"], name: "index_data_access_records_on_account_id_and_accessed_at"
    t.index ["account_id"], name: "index_data_access_records_on_account_id"
    t.index ["record_type", "record_id"], name: "index_data_access_records_on_record_type_and_record_id"
    t.index ["user_id", "accessed_at"], name: "index_data_access_records_on_user_id_and_accessed_at"
    t.index ["user_id"], name: "index_data_access_records_on_user_id"
  end

  create_table "distribution_filter_assignments", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "distribution_filter_id", null: false
    t.bigint "distribution_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "distribution_filter_id", "distribution_id"], name: "idx_distribution_filter_assignments_uniqueness", unique: true
    t.index ["account_id"], name: "index_distribution_filter_assignments_on_account_id"
    t.index ["distribution_filter_id"], name: "idx_on_distribution_filter_id_8620034130"
    t.index ["distribution_id"], name: "index_distribution_filter_assignments_on_distribution_id"
  end

  create_table "distributions", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.bigint "company_id", null: false
    t.string "endpoint_url", null: false
    t.string "authentication_token"
    t.integer "status", default: 0, null: false
    t.integer "request_method", default: 1, null: false
    t.integer "request_format", default: 1, null: false
    t.text "template"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "account_id", null: false
    t.boolean "bidding_enabled", default: true
    t.integer "bidding_timeout_seconds", default: 5
    t.integer "bidding_strategy", default: 0
    t.decimal "base_bid_amount", precision: 10, scale: 2
    t.decimal "min_bid_amount", precision: 10, scale: 2
    t.decimal "max_bid_amount", precision: 10, scale: 2
    t.string "bid_endpoint_url"
    t.string "metadata_requirements"
    t.jsonb "custom_metadata_fields"
    t.index ["account_id", "name"], name: "index_distributions_on_account_id_and_name", unique: true
    t.index ["account_id"], name: "index_distributions_on_account_id"
    t.index ["company_id", "name"], name: "index_distributions_on_company_id_and_name", unique: true
    t.index ["company_id"], name: "index_distributions_on_company_id"
  end

  create_table "filters", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "campaign_id", null: false
    t.bigint "campaign_field_id", null: false
    t.string "type", null: false
    t.string "operator", null: false
    t.string "value"
    t.decimal "min_value", precision: 10, scale: 2
    t.decimal "max_value", precision: 10, scale: 2
    t.string "status", default: "active", null: false
    t.boolean "apply_to_all", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_filters_on_account_id"
    t.index ["campaign_field_id"], name: "index_filters_on_campaign_field_id"
    t.index ["campaign_id"], name: "index_filters_on_campaign_id"
    t.index ["type", "account_id", "campaign_id"], name: "index_filters_on_type_and_account_id_and_campaign_id"
  end

  create_table "headers", force: :cascade do |t|
    t.bigint "distribution_id", null: false
    t.string "name", null: false
    t.string "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["distribution_id", "name"], name: "index_headers_on_distribution_id_and_name", unique: true
    t.index ["distribution_id"], name: "index_headers_on_distribution_id"
  end

  create_table "inbound_webhooks", force: :cascade do |t|
    t.integer "status", default: 0, null: false
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "lead_activity_logs", force: :cascade do |t|
    t.bigint "lead_id", null: false
    t.bigint "user_id"
    t.bigint "account_id", null: false
    t.string "causer_type"
    t.bigint "causer_id"
    t.integer "activity_type", null: false
    t.jsonb "details", default: {}
    t.string "ip_address"
    t.string "user_agent"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_lead_activity_logs_on_account_id"
    t.index ["activity_type"], name: "index_lead_activity_logs_on_activity_type"
    t.index ["causer_type", "causer_id"], name: "index_lead_activity_logs_on_causer"
    t.index ["lead_id", "created_at"], name: "index_lead_activity_logs_on_lead_id_and_created_at"
    t.index ["lead_id"], name: "index_lead_activity_logs_on_lead_id"
    t.index ["user_id"], name: "index_lead_activity_logs_on_user_id"
  end

  create_table "lead_data", force: :cascade do |t|
    t.bigint "lead_id", null: false
    t.bigint "campaign_field_id", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_field_id"], name: "index_lead_data_on_campaign_field_id"
    t.index ["lead_id", "campaign_field_id"], name: "index_lead_data_on_lead_id_and_campaign_field_id", unique: true
    t.index ["lead_id"], name: "index_lead_data_on_lead_id"
  end

  create_table "leads", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "campaign_id", null: false
    t.bigint "source_id"
    t.string "unique_id", null: false
    t.integer "status", default: 0, null: false
    t.string "ip_address"
    t.string "user_agent"
    t.string "referrer"
    t.datetime "first_distributed_at"
    t.integer "distribution_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "bid_request_id"
    t.text "error_message"
    t.index ["account_id", "unique_id"], name: "index_leads_on_account_id_and_unique_id", unique: true
    t.index ["account_id"], name: "index_leads_on_account_id"
    t.index ["bid_request_id"], name: "index_leads_on_bid_request_id"
    t.index ["campaign_id"], name: "index_leads_on_campaign_id"
    t.index ["source_id"], name: "index_leads_on_source_id"
  end

  create_table "list_values", force: :cascade do |t|
    t.string "list_owner_type"
    t.bigint "list_owner_id"
    t.bigint "account_id", null: false
    t.string "list_value", null: false
    t.integer "value_type", default: 0
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "list_owner_type", "list_owner_id", "position"], name: "idx_on_account_id_list_owner_type_list_owner_id_pos_6c38036597"
    t.index ["account_id"], name: "index_list_values_on_account_id"
    t.index ["list_owner_type", "list_owner_id", "position"], name: "index_list_values_on_owner_and_position"
    t.index ["list_owner_type", "list_owner_id"], name: "index_list_values_on_list_owner"
  end

  create_table "mapped_fields", force: :cascade do |t|
    t.bigint "campaign_distribution_id", null: false
    t.integer "campaign_field_id"
    t.string "distribution_field_name", null: false
    t.string "static_value"
    t.integer "value_type", default: 0, null: false
    t.boolean "required", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "preferences"
    t.index ["campaign_distribution_id", "distribution_field_name"], name: "index_mapped_fields_on_campaign_dist_and_field_name", unique: true
    t.index ["campaign_distribution_id"], name: "index_mapped_fields_on_campaign_distribution_id"
  end

  create_table "noticed_events", force: :cascade do |t|
    t.bigint "account_id"
    t.string "type"
    t.string "record_type"
    t.bigint "record_id"
    t.jsonb "params"
    t.integer "notifications_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_noticed_events_on_account_id"
    t.index ["record_type", "record_id"], name: "index_noticed_events_on_record"
  end

  create_table "noticed_notifications", force: :cascade do |t|
    t.bigint "account_id"
    t.string "type"
    t.bigint "event_id", null: false
    t.string "recipient_type", null: false
    t.bigint "recipient_id", null: false
    t.datetime "read_at", precision: nil
    t.datetime "seen_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_noticed_notifications_on_account_id"
    t.index ["event_id"], name: "index_noticed_notifications_on_event_id"
    t.index ["recipient_type", "recipient_id"], name: "index_noticed_notifications_on_recipient"
  end

  create_table "notification_tokens", force: :cascade do |t|
    t.bigint "user_id"
    t.string "token", null: false
    t.string "platform", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_notification_tokens_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "recipient_type", null: false
    t.bigint "recipient_id", null: false
    t.string "type"
    t.jsonb "params"
    t.datetime "read_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "interacted_at", precision: nil
    t.index ["account_id"], name: "index_notifications_on_account_id"
    t.index ["recipient_type", "recipient_id"], name: "index_notifications_on_recipient_type_and_recipient_id"
  end

  create_table "pay_charges", force: :cascade do |t|
    t.string "processor_id", null: false
    t.integer "amount", null: false
    t.integer "amount_refunded"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.jsonb "data"
    t.integer "application_fee_amount"
    t.string "currency"
    t.jsonb "metadata"
    t.integer "subscription_id"
    t.bigint "customer_id"
    t.string "stripe_account"
    t.string "type"
    t.index ["customer_id", "processor_id"], name: "index_pay_charges_on_customer_id_and_processor_id", unique: true
  end

  create_table "pay_customers", force: :cascade do |t|
    t.string "owner_type"
    t.bigint "owner_id"
    t.string "processor"
    t.string "processor_id"
    t.boolean "default"
    t.jsonb "data"
    t.datetime "deleted_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "stripe_account"
    t.string "type"
    t.index ["owner_type", "owner_id", "deleted_at"], name: "customer_owner_processor_index"
    t.index ["processor", "processor_id"], name: "index_pay_customers_on_processor_and_processor_id"
  end

  create_table "pay_merchants", force: :cascade do |t|
    t.string "owner_type"
    t.bigint "owner_id"
    t.string "processor"
    t.string "processor_id"
    t.boolean "default"
    t.jsonb "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type"
    t.index ["owner_type", "owner_id", "processor"], name: "index_pay_merchants_on_owner_type_and_owner_id_and_processor"
  end

  create_table "pay_payment_methods", force: :cascade do |t|
    t.bigint "customer_id"
    t.string "processor_id"
    t.boolean "default"
    t.string "payment_method_type"
    t.jsonb "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "stripe_account"
    t.string "type"
    t.index ["customer_id", "processor_id"], name: "index_pay_payment_methods_on_customer_id_and_processor_id", unique: true
  end

  create_table "pay_subscriptions", id: :serial, force: :cascade do |t|
    t.string "name", null: false
    t.string "processor_id", null: false
    t.string "processor_plan", null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "trial_ends_at", precision: nil
    t.datetime "ends_at", precision: nil
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.string "status"
    t.jsonb "data"
    t.decimal "application_fee_percent", precision: 8, scale: 2
    t.jsonb "metadata"
    t.bigint "customer_id"
    t.datetime "current_period_start"
    t.datetime "current_period_end"
    t.boolean "metered"
    t.string "pause_behavior"
    t.datetime "pause_starts_at"
    t.datetime "pause_resumes_at"
    t.string "payment_method_id"
    t.string "stripe_account"
    t.string "type"
    t.index ["customer_id", "processor_id"], name: "index_pay_subscriptions_on_customer_id_and_processor_id", unique: true
    t.index ["metered"], name: "index_pay_subscriptions_on_metered"
    t.index ["pause_starts_at"], name: "index_pay_subscriptions_on_pause_starts_at"
  end

  create_table "pay_webhooks", force: :cascade do |t|
    t.string "processor"
    t.string "event_type"
    t.jsonb "event"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "plans", force: :cascade do |t|
    t.string "name", null: false
    t.integer "amount", default: 0, null: false
    t.string "interval", null: false
    t.jsonb "details", default: {}, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "trial_period_days", default: 0
    t.boolean "hidden"
    t.string "currency"
    t.integer "interval_count", default: 1
    t.string "description"
    t.string "unit_label"
    t.boolean "charge_per_unit"
    t.string "stripe_id"
    t.string "braintree_id"
    t.string "paddle_billing_id"
    t.string "paddle_classic_id"
    t.string "lemon_squeezy_id"
    t.string "fake_processor_id"
    t.string "contact_url"
  end

  create_table "refer_referral_codes", force: :cascade do |t|
    t.string "referrer_type", null: false
    t.bigint "referrer_id", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "referrals_count", default: 0
    t.integer "visits_count", default: 0
    t.index ["code"], name: "index_refer_referral_codes_on_code", unique: true
    t.index ["referrer_type", "referrer_id"], name: "index_refer_referral_codes_on_referrer"
  end

  create_table "refer_referrals", force: :cascade do |t|
    t.string "referrer_type", null: false
    t.bigint "referrer_id", null: false
    t.string "referee_type", null: false
    t.bigint "referee_id", null: false
    t.bigint "referral_code_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "completed_at"
    t.index ["referee_type", "referee_id"], name: "index_refer_referrals_on_referee"
    t.index ["referral_code_id"], name: "index_refer_referrals_on_referral_code_id"
    t.index ["referrer_type", "referrer_id"], name: "index_refer_referrals_on_referrer"
  end

  create_table "refer_visits", force: :cascade do |t|
    t.bigint "referral_code_id", null: false
    t.string "ip"
    t.text "user_agent"
    t.text "referrer"
    t.string "referring_domain"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["referral_code_id"], name: "index_refer_visits_on_referral_code_id"
  end

  create_table "source_filter_assignments", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "source_filter_id", null: false
    t.bigint "source_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "source_filter_id", "source_id"], name: "idx_source_filter_assignments_uniqueness", unique: true
    t.index ["account_id"], name: "index_source_filter_assignments_on_account_id"
    t.index ["source_filter_id"], name: "index_source_filter_assignments_on_source_filter_id"
    t.index ["source_id"], name: "index_source_filter_assignments_on_source_id"
  end

  create_table "sources", force: :cascade do |t|
    t.string "name", null: false
    t.string "token", null: false
    t.string "status", default: "active", null: false
    t.string "integration_type", null: false
    t.string "payout_method"
    t.string "payout_structure"
    t.decimal "minimum_acceptable_bid", precision: 10, scale: 2
    t.decimal "margin", precision: 10, scale: 2
    t.decimal "payout", precision: 10, scale: 2
    t.decimal "daily_budget", precision: 10, scale: 2
    t.decimal "monthly_budget", precision: 10, scale: 2
    t.text "notes"
    t.bigint "campaign_id", null: false
    t.bigint "company_id", null: false
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_sources_on_account_id"
    t.index ["campaign_id"], name: "index_sources_on_campaign_id"
    t.index ["company_id"], name: "index_sources_on_company_id"
    t.index ["name", "account_id"], name: "index_sources_on_name_and_account_id", unique: true
    t.index ["token"], name: "index_sources_on_token", unique: true
  end

  create_table "standard_fields", force: :cascade do |t|
    t.string "name"
    t.string "label"
    t.integer "data_type"
    t.integer "value_acceptance", default: 0
    t.boolean "required", default: false
    t.text "description"
    t.boolean "is_pii", default: false
    t.boolean "ping_required", default: false
    t.boolean "post_required", default: false
    t.boolean "post_only", default: false
    t.boolean "hide", default: false
    t.string "default_value"
    t.string "example_value"
    t.string "validation_regex"
    t.integer "min_length"
    t.integer "max_length"
    t.decimal "min_value", precision: 10, scale: 2
    t.decimal "max_value", precision: 10, scale: 2
    t.bigint "account_id", null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "name"], name: "index_standard_fields_on_account_id_and_name", unique: true
    t.index ["account_id"], name: "index_standard_fields_on_account_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.string "confirmation_token"
    t.datetime "confirmed_at", precision: nil
    t.datetime "confirmation_sent_at", precision: nil
    t.string "unconfirmed_email"
    t.string "first_name"
    t.string "last_name"
    t.string "time_zone"
    t.datetime "accepted_terms_at", precision: nil
    t.datetime "accepted_privacy_at", precision: nil
    t.datetime "announcements_read_at", precision: nil
    t.boolean "admin"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "invitation_token"
    t.datetime "invitation_created_at", precision: nil
    t.datetime "invitation_sent_at", precision: nil
    t.datetime "invitation_accepted_at", precision: nil
    t.integer "invitation_limit"
    t.string "invited_by_type"
    t.bigint "invited_by_id"
    t.integer "invitations_count", default: 0
    t.string "preferred_language"
    t.boolean "otp_required_for_login"
    t.string "otp_secret"
    t.integer "last_otp_timestep"
    t.text "otp_backup_codes"
    t.jsonb "preferences"
    t.virtual "name", type: :string, as: "(((first_name)::text || ' '::text) || (COALESCE(last_name, ''::character varying))::text)", stored: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["invitation_token"], name: "index_users_on_invitation_token", unique: true
    t.index ["invitations_count"], name: "index_users_on_invitations_count"
    t.index ["invited_by_id"], name: "index_users_on_invited_by_id"
    t.index ["invited_by_type", "invited_by_id"], name: "index_users_on_invited_by_type_and_invited_by_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "validation_rules", force: :cascade do |t|
    t.string "rule_type", null: false
    t.string "validatable_type", null: false
    t.bigint "validatable_id", null: false
    t.bigint "account_id", null: false
    t.string "name", null: false
    t.text "description"
    t.text "condition", null: false
    t.string "error_message", null: false
    t.string "severity", default: "error"
    t.integer "position", default: 0
    t.boolean "active", default: true
    t.jsonb "parameters", default: {}
    t.jsonb "test_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "legacy", default: false
    t.index ["account_id"], name: "index_validation_rules_on_account_id"
    t.index ["rule_type"], name: "index_validation_rules_on_rule_type"
    t.index ["validatable_type", "validatable_id", "name"], name: "index_validation_rules_on_validatable_and_name", unique: true
    t.index ["validatable_type", "validatable_id"], name: "index_validation_rules_on_validatable"
  end

  create_table "vertical_fields", force: :cascade do |t|
    t.bigint "vertical_id", null: false
    t.bigint "account_id", null: false
    t.string "name", null: false
    t.string "label"
    t.integer "data_type", null: false
    t.integer "position"
    t.boolean "required", default: false
    t.boolean "is_pii", default: false
    t.boolean "ping_required", default: false
    t.boolean "post_required", default: false
    t.boolean "post_only", default: false
    t.boolean "hide", default: false
    t.string "default_value"
    t.string "example_value"
    t.integer "value_acceptance"
    t.decimal "min_value"
    t.decimal "max_value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "validation_regex"
    t.integer "min_length"
    t.integer "max_length"
    t.text "description"
    t.index ["account_id", "position"], name: "index_vertical_fields_on_account_id_and_position"
    t.index ["account_id", "vertical_id", "name"], name: "index_vertical_fields_on_account_id_and_vertical_id_and_name", unique: true
    t.index ["account_id"], name: "index_vertical_fields_on_account_id"
    t.index ["vertical_id"], name: "index_vertical_fields_on_vertical_id"
  end

  create_table "verticals", force: :cascade do |t|
    t.string "name"
    t.string "primary_category"
    t.string "secondary_category"
    t.text "description"
    t.boolean "archived", default: false
    t.boolean "base", default: false
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "name"], name: "index_verticals_on_account_id_and_name", unique: true
    t.index ["account_id", "primary_category"], name: "index_verticals_on_account_id_and_primary_category"
    t.index ["account_id"], name: "index_verticals_on_account_id"
  end

  add_foreign_key "account_invitations", "accounts"
  add_foreign_key "account_invitations", "users", column: "invited_by_id"
  add_foreign_key "account_users", "accounts"
  add_foreign_key "account_users", "users"
  add_foreign_key "accounts", "users", column: "owner_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "api_requests", "accounts"
  add_foreign_key "api_tokens", "users"
  add_foreign_key "bid_analytic_snapshots", "accounts"
  add_foreign_key "bid_analytic_snapshots", "campaigns"
  add_foreign_key "bid_analytic_snapshots", "distributions"
  add_foreign_key "bid_requests", "accounts"
  add_foreign_key "bid_requests", "campaigns"
  add_foreign_key "bid_requests", "leads"
  add_foreign_key "bids", "accounts"
  add_foreign_key "bids", "bid_requests"
  add_foreign_key "bids", "distributions"
  add_foreign_key "calculated_fields", "accounts"
  add_foreign_key "calculated_fields", "campaigns", on_delete: :cascade
  add_foreign_key "campaign_distributions", "accounts"
  add_foreign_key "campaign_distributions", "campaigns"
  add_foreign_key "campaign_distributions", "distributions"
  add_foreign_key "campaign_fields", "accounts"
  add_foreign_key "campaign_fields", "campaigns", on_delete: :cascade
  add_foreign_key "campaign_fields", "vertical_fields"
  add_foreign_key "campaigns", "accounts"
  add_foreign_key "campaigns", "verticals", on_delete: :cascade
  add_foreign_key "companies", "accounts"
  add_foreign_key "compliance_records", "accounts"
  add_foreign_key "consent_records", "accounts"
  add_foreign_key "consent_records", "leads"
  add_foreign_key "contacts", "accounts"
  add_foreign_key "contacts", "companies"
  add_foreign_key "data_access_records", "accounts"
  add_foreign_key "data_access_records", "users"
  add_foreign_key "distribution_filter_assignments", "accounts"
  add_foreign_key "distribution_filter_assignments", "distributions"
  add_foreign_key "distribution_filter_assignments", "filters", column: "distribution_filter_id"
  add_foreign_key "distributions", "accounts"
  add_foreign_key "distributions", "companies"
  add_foreign_key "filters", "accounts"
  add_foreign_key "filters", "campaign_fields"
  add_foreign_key "filters", "campaigns"
  add_foreign_key "headers", "distributions"
  add_foreign_key "lead_activity_logs", "accounts"
  add_foreign_key "lead_activity_logs", "leads"
  add_foreign_key "lead_activity_logs", "users"
  add_foreign_key "lead_data", "campaign_fields"
  add_foreign_key "lead_data", "leads"
  add_foreign_key "leads", "accounts"
  add_foreign_key "leads", "bid_requests"
  add_foreign_key "leads", "campaigns"
  add_foreign_key "leads", "sources"
  add_foreign_key "list_values", "accounts"
  add_foreign_key "mapped_fields", "campaign_distributions"
  add_foreign_key "pay_charges", "pay_customers", column: "customer_id"
  add_foreign_key "pay_payment_methods", "pay_customers", column: "customer_id"
  add_foreign_key "pay_subscriptions", "pay_customers", column: "customer_id"
  add_foreign_key "refer_visits", "refer_referral_codes", column: "referral_code_id"
  add_foreign_key "source_filter_assignments", "accounts"
  add_foreign_key "source_filter_assignments", "filters", column: "source_filter_id"
  add_foreign_key "source_filter_assignments", "sources"
  add_foreign_key "sources", "accounts"
  add_foreign_key "sources", "campaigns"
  add_foreign_key "sources", "companies"
  add_foreign_key "standard_fields", "accounts"
  add_foreign_key "validation_rules", "accounts"
  add_foreign_key "vertical_fields", "accounts"
  add_foreign_key "vertical_fields", "verticals"
  add_foreign_key "verticals", "accounts"
end
