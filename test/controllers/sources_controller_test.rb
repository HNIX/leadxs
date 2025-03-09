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
    # Ensure we have proper tenant context
    ActsAsTenant.with_tenant(@account) do
      # Create a new test source with valid attributes for fixed payout method
      source = Source.create!(
        name: "Test Source for Update #{Time.now.to_i}",
        integration_type: "affiliate",
        status: "active",
        campaign: @campaign,
        company: @company,
        payout_method: "fixed",
        payout: 5.0,
        payout_structure: "per_lead"
      )
      
      # Update with valid parameters
      patch source_url(source), params: { 
        source: { 
          name: "Updated Source Name",
          status: "paused",
          minimum_acceptable_bid: 7.0
        } 
      }
      
      # Reload and verify updates
      source.reload
      
      assert_equal "Updated Source Name", source.name
      assert_equal "paused", source.status
      assert_equal 7.0, source.minimum_acceptable_bid
      assert_redirected_to source_url(source)
      
      # Now test updating the payout method from fixed to percentage
      patch source_url(source), params: { 
        source: { 
          payout_method: "percentage",
          margin: 0.25,
          payout: nil  # Must explicitly set payout to nil when changing to percentage
        } 
      }
      
      # Reload and verify updates
      source.reload
      
      assert_equal "percentage", source.payout_method
      assert_equal 0.25, source.margin
      assert_nil source.payout
      assert_redirected_to source_url(source)
    end
  end

  test "should run basic update" do
    # Ensure we have proper tenant context
    ActsAsTenant.with_tenant(@account) do
      # Create a fresh source to test with
      source = Source.create!(
        name: "Source for Update Test",
        integration_type: "affiliate",
        payout_method: "fixed",
        payout: 10.0,
        status: "active",
        campaign: @campaign,
        company: @company
      )
      
      patch source_url(source), params: { 
        source: { 
          name: "Updated Source Name"
        } 
      }
      
      source.reload
      assert_equal "Updated Source Name", source.name
      assert_redirected_to source_url(source)
    end
  end
  
  test "should destroy source" do
    source_campaign = @source.campaign
    
    assert_difference("Source.where(id: @source.id).count", -1) do
      delete source_url(@source)
    end
    
    assert_redirected_to campaign_sources_url(source_campaign)
  end
  
  test "should regenerate token" do
    # Ensure we have proper tenant context
    ActsAsTenant.with_tenant(@account) do
      # Create a new test source with valid attributes for fixed payout method
      source = Source.create!(
        name: "Test Source for Token Regeneration #{Time.now.to_i}",
        integration_type: "affiliate",
        status: "active",
        campaign: @campaign,
        company: @company,
        payout_method: "fixed",
        payout: 5.0,
        payout_structure: "per_lead"
      )
      
      # Store the original token
      original_token = source.token
      
      # Use a deterministic value for the new token to make the test more reliable
      expected_token = "predictable_test_token_#{Time.now.to_i}"
      
      # Mock SecureRandom to return our predictable value
      SecureRandom.stub(:urlsafe_base64, expected_token) do
        post regenerate_token_source_url(source)
      end
      
      # Reload and verify the token has changed to our expected value
      source.reload
      assert_not_equal original_token, source.token
      assert_equal expected_token, source.token
      assert_redirected_to source_url(source)
      
      # Also verify flash notice
      assert_equal "API token was successfully regenerated.", flash[:notice]
    end
  end
  
  # We no longer need this test since we've fixed test_should_regenerate_token
  # and it now covers all the same functionality
  # test "should run basic token regeneration" do
  #   ActsAsTenant.with_tenant(@account) do
  #     source = Source.create!(...)
  #     # ...
  #   end
  # end
end