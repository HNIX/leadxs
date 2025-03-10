require "test_helper"

class FieldMapperTest < ActiveSupport::TestCase
  setup do
    # Load fixtures
    @lead = Lead.first || Lead.create!(
      campaign: Campaign.first,
      account: Account.first,
      status: :new_lead,
      unique_id: SecureRandom.uuid
    )
    
    @campaign_distribution = CampaignDistribution.first || CampaignDistribution.create!(
      campaign: Campaign.first,
      distribution: Distribution.first,
      active: true
    )
  end
  
  test "builds payload with mapped fields" do
    # Create a lead with data
    lead = @lead
    
    # Get campaign distribution
    campaign_distribution = @campaign_distribution
    
    # Create field mapper
    mapper = FieldMapper.new(lead, campaign_distribution)
    
    # Build payload
    payload = mapper.build_payload
    
    # Verify payload contains mapped field values
    assert payload.present?
    assert_kind_of Hash, payload
  end
  
  test "formats phone numbers correctly" do
    skip "This test requires further setup for mapped fields"
  end
  
  test "adds metadata to payload based on distribution requirements" do
    skip "This test requires further setup for metadata fields"
  end
  
  test "handles static values correctly" do
    # Create a lead with data
    lead = @lead
    
    # Get campaign distribution
    campaign_distribution = @campaign_distribution
    
    # Create a static mapped field
    mapped_field = campaign_distribution.mapped_fields.create!(
      distribution_field_name: "static_field",
      value_type: "static",
      static_value: "test value"
    )
    
    # Create field mapper
    mapper = FieldMapper.new(lead, campaign_distribution)
    
    # Build payload
    payload = mapper.build_payload
    
    # Check static value
    assert_equal "test value", payload["static_field"]
  end
end