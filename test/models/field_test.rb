# frozen_string_literal: true

require "test_helper"

class FieldTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @farm = farms(:one)
    @field = Field.new(
      farm: @farm,
      user: @user,
      name: "テスト圃場"
    )
  end

  test "should be valid" do
    assert @field.valid?
  end

  test "name should be present" do
    @field.name = "   "
    assert_not @field.valid?
  end

  test "name should not be too long" do
    @field.name = "a" * 101
    assert_not @field.valid?
  end


  test "name should be unique per user" do
    duplicate_field = @field.dup
    @field.save
    assert_not duplicate_field.valid?
  end

  test "name uniqueness should be case insensitive" do
    duplicate_field = @field.dup
    duplicate_field.name = @field.name.upcase
    @field.save
    assert_not duplicate_field.valid?
  end

  test "should belong to user" do
    assert_respond_to @field, :user
    assert_equal @user, @field.user
  end


  test "display_name should return name when present" do
    assert_equal @field.name, @field.display_name
  end

  test "display_name should return fallback when name blank" do
    @field.name = "   "
    @field.save
    assert_equal "圃場 ##{@field.id}", @field.display_name
  end

  test "by_user scope should filter by user" do
    user2 = User.create!(
      email: 'user2_scope@example.com',
      name: 'User 2',
      google_id: "google_#{SecureRandom.hex(8)}"
    )
    
    field1 = Field.create!(
      farm: @farm,
      user: @user,
      name: "User 1 Field"
    )
    
    field2 = Field.create!(
      farm: @farm,
      user: user2,
      name: "User 2 Field"
    )
    
    user1_fields = Field.by_user(@user)
    assert_includes user1_fields, field1
    assert_not_includes user1_fields, field2
  end

  test "recent scope should order by created_at desc" do
    field1 = Field.create!(
      farm: @farm,
      user: @user,
      name: "Field 1"
    )
    
    field2 = Field.create!(
      farm: @farm,
      user: @user,
      name: "Field 2"
    )
    
    recent_fields = Field.recent
    assert_equal field2, recent_fields.first
    assert_equal field1, recent_fields.second
  end

  test "by_region scope should filter by region" do
    field_jp = Field.create!(
      farm: @farm,
      user: @user,
      name: "JP Field",
      region: "jp"
    )
    
    field_us = Field.create!(
      farm: @farm,
      user: @user,
      name: "US Field",
      region: "us"
    )
    
    field_no_region = Field.create!(
      farm: @farm,
      user: @user,
      name: "No Region Field"
    )
    
    jp_fields = Field.by_region("jp")
    assert_includes jp_fields, field_jp
    assert_not_includes jp_fields, field_us
    assert_not_includes jp_fields, field_no_region
    
    us_fields = Field.by_region("us")
    assert_includes us_fields, field_us
    assert_not_includes us_fields, field_jp
  end

  test "area should be positive" do
    @field.area = -1
    assert_not @field.valid?
    
    @field.area = 0
    assert_not @field.valid?
    
    @field.area = 100
    assert @field.valid?
  end

  test "area can be nil" do
    @field.area = nil
    assert @field.valid?
  end

  test "daily_fixed_cost should be non-negative" do
    @field.daily_fixed_cost = -1
    assert_not @field.valid?
    
    @field.daily_fixed_cost = 0
    assert @field.valid?
    
    @field.daily_fixed_cost = 5000
    assert @field.valid?
  end

  test "daily_fixed_cost can be nil" do
    @field.daily_fixed_cost = nil
    assert @field.valid?
  end

  test "to_agrr_config should return proper configuration" do
    @field.save!
    config = @field.to_agrr_config
    
    assert_equal @field.id.to_s, config[:field_id]
    assert_equal @field.name, config[:name]
    assert_equal @field.area, config[:area]
    assert_equal @field.daily_fixed_cost, config[:daily_fixed_cost]
  end

  test "to_agrr_config should handle fields with area and cost" do
    @field.area = 1000.0
    @field.daily_fixed_cost = 5000.0
    @field.save!
    
    config = @field.to_agrr_config
    
    assert_equal 1000.0, config[:area]
    assert_equal 5000.0, config[:daily_fixed_cost]
  end
end
