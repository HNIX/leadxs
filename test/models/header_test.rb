require "test_helper"

class HeaderTest < ActiveSupport::TestCase
  setup do
    @distribution = distributions(:one)
    @header = Header.new(
      distribution: @distribution,
      name: "X-Custom-Header",
      value: "custom value"
    )
  end

  test "valid header" do
    assert @header.valid?
  end

  test "requires distribution" do
    @header.distribution = nil
    assert_not @header.valid?
  end

  test "requires name" do
    @header.name = nil
    assert_not @header.valid?
    assert_includes @header.errors[:name], "can't be blank"
  end

  test "requires value" do
    @header.value = nil
    assert_not @header.valid?
    assert_includes @header.errors[:value], "can't be blank"
  end

  test "validates uniqueness of name within distribution" do
    @header.save
    duplicate = Header.new(
      distribution: @distribution,
      name: "X-Custom-Header",
      value: "different value"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "common_headers returns an array of common HTTP headers" do
    headers = Header.common_headers
    assert_kind_of Array, headers
    assert_includes headers, "Authorization"
    assert_includes headers, "Content-Type"
    assert_includes headers, "Accept"
  end
end
