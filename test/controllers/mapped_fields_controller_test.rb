require "test_helper"

class MappedFieldsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @account = accounts(:one)
    @campaign_distribution = campaign_distributions(:one)
    @mapped_field = mapped_fields(:first_name)
    
    sign_in @user
    
    # Use the account for multi-tenancy
    Current.account = @account
  end

  test "should get index" do
    get campaign_distribution_mapped_fields_path(@campaign_distribution)
    assert_response :success
  end

  test "should update mappings" do
    # The controller expects 'mappings' parameter but not wrapped in another hash
    patch update_mappings_campaign_distribution_mapped_fields_path(@campaign_distribution), params: {
      mappings: {
        @mapped_field.id.to_s => {
          campaign_field_id: campaign_fields(:two).id,
          distribution_field_name: "updatedFieldName",
          value_type: "dynamic",
          required: true
        }
      }
    }
    
    assert_redirected_to campaign_distribution_path(@campaign_distribution)
  end
end
