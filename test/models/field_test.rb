# frozen_string_literal: true

require "test_helper"

class FieldTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @field = Field.new(
      user: @user,
      name: "テスト圃場",
      latitude: 35.6812,
      longitude: 139.7671
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

  test "latitude should be present" do
    @field.latitude = nil
    assert_not @field.valid?
  end

  test "latitude should be within valid range" do
    @field.latitude = -91
    assert_not @field.valid?
    
    @field.latitude = 91
    assert_not @field.valid?
    
    @field.latitude = 35.6812
    assert @field.valid?
  end

  test "longitude should be present" do
    @field.longitude = nil
    assert_not @field.valid?
  end

  test "longitude should be within valid range" do
    @field.longitude = -181
    assert_not @field.valid?
    
    @field.longitude = 181
    assert_not @field.valid?
    
    @field.longitude = 139.7671
    assert @field.valid?
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

  test "coordinates method should return array" do
    expected_coordinates = [@field.latitude, @field.longitude]
    assert_equal expected_coordinates, @field.coordinates
  end

  test "has_coordinates? should return true when both coordinates present" do
    assert @field.has_coordinates?
  end

  test "has_coordinates? should return false when latitude missing" do
    @field.latitude = nil
    assert_not @field.has_coordinates?
  end

  test "has_coordinates? should return false when longitude missing" do
    @field.longitude = nil
    assert_not @field.has_coordinates?
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
      user: @user,
      name: "User 1 Field",
      latitude: 35.6812,
      longitude: 139.7671
    )
    
    field2 = Field.create!(
      user: user2,
      name: "User 2 Field",
      latitude: 35.6812,
      longitude: 139.7671
    )
    
    user1_fields = Field.by_user(@user)
    assert_includes user1_fields, field1
    assert_not_includes user1_fields, field2
  end

  test "recent scope should order by created_at desc" do
    field1 = Field.create!(
      user: @user,
      name: "Field 1",
      latitude: 35.6812,
      longitude: 139.7671
    )
    
    field2 = Field.create!(
      user: @user,
      name: "Field 2",
      latitude: 35.6812,
      longitude: 139.7671
    )
    
    recent_fields = Field.recent
    assert_equal field2, recent_fields.first
    assert_equal field1, recent_fields.second
  end
end
