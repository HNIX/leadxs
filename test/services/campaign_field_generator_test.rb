require "test_helper"

class CampaignFieldGeneratorTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @vertical = verticals(:home_services)
    @vertical_fields = @vertical.vertical_fields
    
    # Store the original callback status so we can restore it
    @original_callback_chain = Campaign._create_callbacks.deep_dup
    
    # Create a method that does nothing, instead of removing the callback
    # This way we don't have to worry about restoring a nonexistent callback
    Campaign.class_eval do
      def skip_generate_fields_from_vertical
        # Do nothing, effectively skipping the field generation
      end
    end
    
    # Replace the actual method with our empty one
    Campaign.skip_callback(:create, :after, :generate_fields_from_vertical)
    Campaign.set_callback(:create, :after, :skip_generate_fields_from_vertical)
    
    @campaign = Campaign.new(
      account: @account,
      vertical: @vertical,
      name: "Test Campaign",
      status: "draft",
      campaign_type: "ping_post",
      distribution_method: "highest_bid"
    )
  end
  
  teardown do
    # Restore the original callbacks
    Campaign._create_callbacks.clear
    @original_callback_chain.each do |callback|
      Campaign._create_callbacks.append(callback)
    end
    
    # Remove our temporary method
    Campaign.class_eval do
      remove_method :skip_generate_fields_from_vertical if method_defined?(:skip_generate_fields_from_vertical)
    end
  end

  test "should generate campaign fields from vertical fields" do
    # Save without auto-generating fields
    @campaign.save!
    
    # Ensure no fields were created automatically
    assert_equal 0, @campaign.campaign_fields.count
    
    # Generate fields with the service
    generator = CampaignFieldGenerator.new(@campaign)
    generator.generate_fields!
    
    # Verify fields were created
    @campaign.reload
    assert_equal @vertical_fields.count, @campaign.campaign_fields.count
    
    # Verify field attributes were copied correctly
    @vertical_fields.each do |vertical_field|
      campaign_field = @campaign.campaign_fields.find_by(name: vertical_field.name)
      
      assert_not_nil campaign_field, "Campaign field for #{vertical_field.name} not found"
      assert_equal vertical_field.name, campaign_field.name
      assert_equal vertical_field.label, campaign_field.label
      assert_equal vertical_field.data_type, campaign_field.data_type
      assert_equal vertical_field.position, campaign_field.position
      assert_equal vertical_field.required, campaign_field.required
      assert_equal vertical_field.is_pii, campaign_field.is_pii
      assert_equal vertical_field.ping_required, campaign_field.ping_required
      assert_equal vertical_field.post_required, campaign_field.post_required
      assert_equal vertical_field.post_only, campaign_field.post_only
      assert_equal vertical_field.hide, campaign_field.hide
      assert_equal vertical_field.value_acceptance, campaign_field.value_acceptance
      assert_equal vertical_field.id, campaign_field.vertical_field_id
    end
  end
  
  test "should copy list values from vertical fields" do
    # Find a vertical field with list values
    list_field = vertical_fields(:list_field)
    assert_equal 'list', list_field.value_acceptance
    assert list_field.list_values.count > 0, "Vertical field should have list values for this test"
    
    # Save without auto-generating fields
    @campaign.save!
    
    # Generate fields with the service
    generator = CampaignFieldGenerator.new(@campaign)
    generator.generate_fields!
    
    # Find the corresponding campaign field
    @campaign.reload
    campaign_field = @campaign.campaign_fields.find_by(name: list_field.name)
    
    # Verify list values were copied
    assert_equal list_field.list_values.count, campaign_field.list_values.count
    
    # Verify list value attributes
    list_field.list_values.order(position: :asc).each_with_index do |vertical_list_value, index|
      campaign_list_value = campaign_field.list_values.order(position: :asc)[index]
      
      assert_equal vertical_list_value.list_value, campaign_list_value.list_value
      assert_equal vertical_list_value.value_type, campaign_list_value.value_type
      assert_equal vertical_list_value.position, campaign_list_value.position
    end
  end
  
  test "should not create duplicate fields" do
    # Save campaign without auto-generating fields
    @campaign.save!
    
    # Create some fields manually
    first_field = @campaign.campaign_fields.create!(
      name: "first_name",
      label: "First Name",
      field_type: "text",
      data_type: "text",
      position: 1,
      account_id: @account.id
    )
    
    second_field = @campaign.campaign_fields.create!(
      name: "last_name",
      label: "Last Name",
      field_type: "text",
      data_type: "text",
      position: 2,
      account_id: @account.id
    )
    
    # Verify fields were created
    @campaign.reload
    initial_count = @campaign.campaign_fields.count
    assert_equal 2, initial_count, "Campaign should have 2 manually created fields"
    
    # Try to generate fields again (including ones with the same names)
    generator = CampaignFieldGenerator.new(@campaign)
    generator.generate_fields!
    
    # Verify no duplicate fields were created for existing field names
    @campaign.reload
    assert @campaign.campaign_fields.count > initial_count, "New fields should be created"
    assert_equal 1, @campaign.campaign_fields.where(name: "first_name").count, "No duplicate 'first_name' field should be created"
    assert_equal 1, @campaign.campaign_fields.where(name: "last_name").count, "No duplicate 'last_name' field should be created"
  end
end