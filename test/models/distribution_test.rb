require "test_helper"

class DistributionTest < ActiveSupport::TestCase
  test "endpoint types and authentication methods should be defined properly" do
    # Create a new distribution object
    distribution = Distribution.new(
      account_id: 1,
      company_id: 1,
      name: "Test Distribution",
      endpoint_url: "https://example.com/api"
    )
    
    # Check enum definitions
    assert_includes Distribution.endpoint_types.keys, "post_only"
    assert_includes Distribution.endpoint_types.keys, "ping_post"
    assert_includes Distribution.endpoint_types.keys, "ping_only"
    
    assert_includes Distribution.authentication_methods.keys, "none"
    assert_includes Distribution.authentication_methods.keys, "token"
    assert_includes Distribution.authentication_methods.keys, "basic_auth"
    assert_includes Distribution.authentication_methods.keys, "oauth2"
    assert_includes Distribution.authentication_methods.keys, "jwt"
    
    # Verify default values
    assert distribution.endpoint_type_post_only?
    assert distribution.authentication_method_none?
  end
end
