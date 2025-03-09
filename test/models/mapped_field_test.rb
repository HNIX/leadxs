require "test_helper"

class MappedFieldTest < ActiveSupport::TestCase
  setup do
    @campaign_distribution = campaign_distributions(:one)
    @campaign_field = campaign_fields(:one) # Use the "one" fixture instead of "name"
    # Use a unique distribution_field_name for each test
    @mapped_field = MappedField.new(
      campaign_distribution: @campaign_distribution,
      campaign_field_id: @campaign_field.id,
      distribution_field_name: "test_field_#{Time.now.to_i}_#{rand(1000)}",
      value_type: :dynamic,
      required: true
    )
  end

  test "valid mapped field" do
    assert @mapped_field.valid?
  end

  test "requires campaign_distribution" do
    @mapped_field.campaign_distribution = nil
    assert_not @mapped_field.valid?
  end

  test "requires distribution_field_name" do
    @mapped_field.distribution_field_name = nil
    assert_not @mapped_field.valid?
    assert_includes @mapped_field.errors[:distribution_field_name], "can't be blank"
  end

  test "validates uniqueness of distribution_field_name within campaign_distribution" do
    @mapped_field.save
    field_name = @mapped_field.distribution_field_name
    duplicate = MappedField.new(
      campaign_distribution: @campaign_distribution,
      distribution_field_name: field_name,
      value_type: :dynamic
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:distribution_field_name], "has already been taken"
  end

  test "allows campaign_field_id to be nil" do
    @mapped_field.campaign_field_id = nil
    assert @mapped_field.valid?
  end

  test "requires static_value when value_type is static" do
    @mapped_field.value_type = :static
    @mapped_field.static_value = nil
    assert_not @mapped_field.valid?
    assert_includes @mapped_field.errors[:static_value], "can't be blank"

    @mapped_field.static_value = "test value"
    assert @mapped_field.valid?
  end

  test "does not require static_value when value_type is dynamic" do
    @mapped_field.value_type = :dynamic
    @mapped_field.static_value = nil
    assert @mapped_field.valid?
  end

  test "has default value_type of dynamic" do
    field = MappedField.new
    assert_equal "dynamic", field.value_type
  end

  test "campaign_field method returns associated campaign field" do
    @mapped_field.save
    assert_equal @campaign_field, @mapped_field.campaign_field
  end

  test "campaign_field method returns nil if campaign_field_id is nil" do
    @mapped_field.campaign_field_id = nil
    @mapped_field.save
    assert_nil @mapped_field.campaign_field
  end
end
