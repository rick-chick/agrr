# frozen_string_literal: true

require "test_helper"

class CropTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
  end

  test "should prevent creating 21st crop for user" do
    # Create 20 crops (上限)
    20.times do |i|
      create(:crop, user: @user, name: "作物 #{i+1}", is_reference: false)
    end
    
    # Attempt to create 21st crop
    crop = Crop.new(user: @user, name: "作物 21", is_reference: false)
    assert_not crop.valid?
    assert_includes crop.errors[:user], "作成できるCropは20件までです"
  end

  test "should allow creating crops when under limit" do
    # Create 19 crops
    19.times do |i|
      create(:crop, user: @user, name: "作物 #{i+1}", is_reference: false)
    end
    
    # 20th crop should be valid
    crop = Crop.new(user: @user, name: "作物 20", is_reference: false)
    assert crop.valid?
  end

  test "should not count reference crops towards limit" do
    # Create 20 reference crops
    20.times do |i|
      create(:crop, name: "参照作物 #{i+1}", is_reference: true, user: nil)
    end
    
    # User should still be able to create 20 crops
    crop = Crop.new(user: @user, name: "ユーザー作物", is_reference: false)
    assert crop.valid?
  end

  test "should allow updating existing crop" do
    # Create 20 crops
    20.times do |i|
      create(:crop, user: @user, name: "作物 #{i+1}", is_reference: false)
    end
    
    # Update should work (自分自身を除く)
    first_crop = @user.crops.first
    first_crop.name = "更新された作物"
    assert first_crop.valid?
  end

  test "should allow different users to have their own 20 crops" do
    @user2 = create(:user)
    
    # Each user creates 20 crops
    20.times do |i|
      create(:crop, user: @user, name: "User1 作物 #{i+1}", is_reference: false)
      create(:crop, user: @user2, name: "User2 作物 #{i+1}", is_reference: false)
    end
    
    # Both users should be at limit
    assert_not Crop.new(user: @user, name: "New", is_reference: false).valid?
    assert_not Crop.new(user: @user2, name: "New", is_reference: false).valid?
  end

  test "should not validate if user is nil" do
    crop = Crop.new(user: nil, name: "作物", is_reference: false)
    # No validation error for missing user
    crop.valid? # triggers validations
    assert_equal 0, crop.errors[:user].count
  end
end
