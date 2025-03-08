require "test_helper"

class SourcesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  
  setup do
    @account = accounts(:one)
    @user = users(:one)
    @campaign = campaigns(:one)
    @company = companies(:one)
    @source = sources(:one)
    
    sign_in @user
    ActsAsTenant.current_tenant = @account
  end
  
  teardown do
    ActsAsTenant.current_tenant = nil
  end
  
  test "should get index" do
    get campaign_sources_url(@campaign)
    assert_response :success
  end
  
  test "should get new" do
    get new_campaign_source_url(@campaign)
    assert_response :success
  end
  
  test "should create source" do
    assert_difference("@campaign.sources.count") do
      post campaign_sources_url(@campaign), params: { 
        source: { 
          name: "New Test Source", 
          integration_type: "affiliate", 
          status: "active", 
          company_id: @company.id 
        } 
      }
    end
    
    new_source = Source.find_by(name: "New Test Source")
    assert_not_nil new_source
    assert_redirected_to source_url(new_source)
  end
  
  test "should show source" do
    get source_url(@source)
    assert_response :success
  end
  
  test "should get edit" do
    get edit_source_url(@source)
    assert_response :success
  end
  
  test "should update source" do
    patch source_url(@source), params: { 
      source: { 
        name: "Updated Source Name", 
        integration_type: "web_form", 
        status: "paused" 
      } 
    }
    
    @source.reload
    assert_equal "Updated Source Name", @source.name
    assert_equal "web_form", @source.integration_type
    assert_equal "paused", @source.status
    assert_redirected_to source_url(@source)
  end
  
  test "should destroy source" do
    source_campaign = @source.campaign
    
    assert_difference("Source.where(id: @source.id).count", -1) do
      delete source_url(@source)
    end
    
    assert_redirected_to campaign_sources_url(source_campaign)
  end
  
  test "should regenerate token" do
    original_token = @source.token
    post regenerate_token_source_url(@source)
    
    @source.reload
    assert_not_equal original_token, @source.token
    assert_redirected_to source_url(@source)
  end
end