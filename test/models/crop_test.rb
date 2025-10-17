# frozen_string_literal: true

require 'test_helper'

class CropTest < ActiveSupport::TestCase
  def setup
    @user = users(:two)  # 一般ユーザー
    @admin = users(:one) # 管理者ユーザー
  end

  test "should create crop with valid attributes" do
    crop = Crop.new(
      name: "稲",
      variety: "コシヒカリ",
      user_id: @user.id,
      is_reference: false
    )
    assert crop.valid?
    assert crop.save
  end

  test "should require name" do
    crop = Crop.new(
      variety: "コシヒカリ",
      user_id: @user.id,
      is_reference: false
    )
    assert_not crop.valid?
    assert_includes crop.errors[:name], "can't be blank"
  end

  test "should allow user_id to be blank for reference crops" do
    crop = Crop.new(
      name: "参照稲",
      variety: "参照品種",
      is_reference: true
    )
    assert crop.valid?
  end

  test "should have crop_stages association" do
    crop = Crop.create!(
      name: "稲",
      user_id: @user.id,
      is_reference: false
    )
    
    stage = crop.crop_stages.create!(
      name: "発芽期",
      order: 1
    )
    
    assert_equal 1, crop.crop_stages.count
    assert_equal "発芽期", crop.crop_stages.first.name
  end

  test "should have temperature_requirement through crop_stages" do
    crop = Crop.create!(
      name: "稲",
      user_id: @user.id,
      is_reference: false
    )
    
    stage = crop.crop_stages.create!(
      name: "発芽期",
      order: 1
    )
    
    stage.create_temperature_requirement!(
      base_temperature: 10,
      optimal_min: 15,
      optimal_max: 25,
      low_stress_threshold: 5,
      high_stress_threshold: 30,
      frost_threshold: 0,
      sterility_risk_threshold: 35
    )
    
    assert_not_nil stage.temperature_requirement
    assert_equal 10, stage.temperature_requirement.base_temperature
  end

  test "should have sunshine_requirement through crop_stages" do
    crop = Crop.create!(
      name: "稲",
      user_id: @user.id,
      is_reference: false
    )
    
    stage = crop.crop_stages.create!(
      name: "開花期",
      order: 2
    )
    
    stage.create_sunshine_requirement!(
      minimum_sunshine_hours: 8,
      target_sunshine_hours: 12
    )
    
    assert_not_nil stage.sunshine_requirement
    assert_equal 8, stage.sunshine_requirement.minimum_sunshine_hours
  end

  test "should order crop_stages by order" do
    crop = Crop.create!(
      name: "稲",
      user_id: @user.id,
      is_reference: false
    )
    
    stage3 = crop.crop_stages.create!(name: "成熟期", order: 3)
    stage1 = crop.crop_stages.create!(name: "発芽期", order: 1)
    stage2 = crop.crop_stages.create!(name: "開花期", order: 2)
    
    ordered_stages = crop.crop_stages.order(:order)
    assert_equal [stage1, stage2, stage3], ordered_stages.to_a
  end

  test "should belong to user" do
    crop = Crop.create!(
      name: "稲",
      user_id: @user.id,
      is_reference: false
    )
    
    assert_equal @user, crop.user
  end

  test "is_reference should default to false" do
    crop = Crop.create!(
      name: "稲",
      user_id: @user.id
    )
    
    assert_equal false, crop.is_reference
  end

  test "should be able to set is_reference to true" do
    crop = Crop.create!(
      name: "参照稲",
      user_id: @admin.id,
      is_reference: true
    )
    
    assert_equal true, crop.is_reference
  end

  test "should allow same name for different users" do
    Crop.create!(
      name: "稲",
      user_id: @user.id,
      is_reference: false
    )
    
    crop2 = Crop.new(
      name: "稲",
      user_id: @admin.id,
      is_reference: false
    )
    
    assert crop2.valid?
  end

  test "should allow same name for reference and user crops" do
    Crop.create!(
      name: "稲",
      user_id: @admin.id,
      is_reference: true
    )
    
    crop2 = Crop.new(
      name: "稲",
      user_id: @user.id,
      is_reference: false
    )
    
    assert crop2.valid?
  end

  test "should save crop with area_per_unit" do
    crop = Crop.create!(
      name: "稲",
      user_id: @user.id,
      is_reference: false,
      area_per_unit: 100.0
    )
    
    assert_equal 100.0, crop.area_per_unit
  end

  test "should save crop with revenue_per_area" do
    crop = Crop.create!(
      name: "稲",
      user_id: @user.id,
      is_reference: false,
      area_per_unit: 100.0,
      revenue_per_area: 500000.0
    )
    
    assert_equal 100.0, crop.area_per_unit
    assert_equal 500000.0, crop.revenue_per_area
  end

  test "should allow nil revenue_per_area" do
    crop = Crop.create!(
      name: "稲",
      user_id: @user.id,
      is_reference: false,
      area_per_unit: 100.0,
      revenue_per_area: nil
    )
    
    assert_equal 100.0, crop.area_per_unit
    assert_nil crop.revenue_per_area
  end

  test "should not allow negative area_per_unit" do
    crop = Crop.new(
      name: "稲",
      user_id: @user.id,
      is_reference: false,
      area_per_unit: -10.0
    )
    
    assert_not crop.valid?
    assert_includes crop.errors[:area_per_unit], "must be greater than 0"
  end

  test "should not allow negative revenue_per_area" do
    crop = Crop.new(
      name: "稲",
      user_id: @user.id,
      is_reference: false,
      revenue_per_area: -1000.0
    )
    
    assert_not crop.valid?
    assert_includes crop.errors[:revenue_per_area], "must be greater than or equal to 0"
  end

  test "should allow zero revenue_per_area" do
    crop = Crop.create!(
      name: "稲",
      user_id: @user.id,
      is_reference: false,
      area_per_unit: 100.0,
      revenue_per_area: 0.0
    )
    
    assert crop.valid?
    assert_equal 0.0, crop.revenue_per_area
  end

  test "to_agrr_requirement should return valid hash structure" do
    crop = Crop.create!(
      name: "rice",
      variety: "Koshihikari",
      user_id: @user.id,
      is_reference: false
    )
    
    stage1 = crop.crop_stages.create!(name: "germination", order: 1)
    stage1.create_temperature_requirement!(
      base_temperature: 10.0,
      optimal_min: 20.0,
      optimal_max: 30.0
    )
    stage1.create_thermal_requirement!(required_gdd: 200.0)
    
    stage2 = crop.crop_stages.create!(name: "flowering", order: 2)
    stage2.create_temperature_requirement!(
      base_temperature: 10.0,
      optimal_min: 22.0,
      optimal_max: 28.0
    )
    stage2.create_thermal_requirement!(required_gdd: 800.0)
    
    result = crop.to_agrr_requirement
    
    assert_equal "rice", result[:crop_name]
    assert_equal "Koshihikari", result[:variety]
    assert_equal 10.0, result[:base_temperature]
    assert_equal 1000.0, result[:gdd_requirement] # 200 + 800
    
    assert_equal 2, result[:stages].length
    assert_equal "germination", result[:stages][0][:name]
    assert_equal 200.0, result[:stages][0][:gdd_requirement]
    assert_equal 20.0, result[:stages][0][:optimal_temp_min]
    assert_equal 30.0, result[:stages][0][:optimal_temp_max]
    
    assert_equal "flowering", result[:stages][1][:name]
    assert_equal 800.0, result[:stages][1][:gdd_requirement]
    assert_equal 22.0, result[:stages][1][:optimal_temp_min]
    assert_equal 28.0, result[:stages][1][:optimal_temp_max]
  end

  test "to_agrr_requirement should raise error when crop has no stages" do
    crop = Crop.create!(
      name: "rice",
      variety: "Koshihikari",
      user_id: @user.id,
      is_reference: false
    )
    
    error = assert_raises(StandardError) do
      crop.to_agrr_requirement
    end
    
    assert_match /has no growth stages/, error.message
    assert_match /rice/, error.message
  end

  test "to_agrr_requirement should handle nil variety" do
    crop = Crop.create!(
      name: "rice",
      variety: nil,
      user_id: @user.id,
      is_reference: false
    )
    
    result = crop.to_agrr_requirement
    
    assert_equal "rice", result[:crop_name]
    assert_equal "", result[:variety]
  end

  test "to_agrr_requirement should raise error when base_temperature is nil" do
    crop = Crop.create!(
      name: "rice",
      variety: "Koshihikari",
      user_id: @user.id,
      is_reference: false
    )
    
    stage = crop.crop_stages.create!(name: "germination", order: 1)
    stage.create_temperature_requirement!(
      base_temperature: nil,
      optimal_min: 20.0,
      optimal_max: 30.0
    )
    stage.create_thermal_requirement!(required_gdd: 200.0)
    
    error = assert_raises(StandardError) do
      crop.to_agrr_requirement
    end
    
    assert_match /invalid base_temperature/, error.message
    assert_match /rice/, error.message
  end

  test "to_agrr_requirement should raise error when base_temperature is zero" do
    crop = Crop.create!(
      name: "rice",
      variety: "Koshihikari",
      user_id: @user.id,
      is_reference: false
    )
    
    stage = crop.crop_stages.create!(name: "germination", order: 1)
    stage.create_temperature_requirement!(
      base_temperature: 0.0,
      optimal_min: 20.0,
      optimal_max: 30.0
    )
    stage.create_thermal_requirement!(required_gdd: 200.0)
    
    error = assert_raises(StandardError) do
      crop.to_agrr_requirement
    end
    
    assert_match /invalid base_temperature/, error.message
    assert_match /0.0/, error.message
  end

  test "to_agrr_requirement should raise error when base_temperature is negative" do
    crop = Crop.create!(
      name: "rice",
      variety: "Koshihikari",
      user_id: @user.id,
      is_reference: false
    )
    
    stage = crop.crop_stages.create!(name: "germination", order: 1)
    stage.create_temperature_requirement!(
      base_temperature: -5.0,
      optimal_min: 20.0,
      optimal_max: 30.0
    )
    stage.create_thermal_requirement!(required_gdd: 200.0)
    
    error = assert_raises(StandardError) do
      crop.to_agrr_requirement
    end
    
    assert_match /invalid base_temperature/, error.message
    assert_match /-5.0/, error.message
  end

  # グループ機能のテスト
  test "should save crop with empty groups by default" do
    crop = Crop.create!(
      name: "稲",
      user_id: @user.id,
      is_reference: false
    )
    
    assert_equal [], crop.groups
  end

  test "should save crop with single group" do
    crop = Crop.create!(
      name: "稲",
      user_id: @user.id,
      is_reference: false,
      groups: ["穀物"]
    )
    
    assert_equal ["穀物"], crop.groups
  end

  test "should save crop with multiple groups" do
    crop = Crop.create!(
      name: "稲",
      user_id: @user.id,
      is_reference: false,
      groups: ["穀物", "水田作物", "主食"]
    )
    
    assert_equal ["穀物", "水田作物", "主食"], crop.groups
  end

  test "should persist groups after reload" do
    crop = Crop.create!(
      name: "稲",
      user_id: @user.id,
      is_reference: false,
      groups: ["穀物", "水田作物"]
    )
    
    crop.reload
    assert_equal ["穀物", "水田作物"], crop.groups
  end

  test "should update groups" do
    crop = Crop.create!(
      name: "稲",
      user_id: @user.id,
      is_reference: false,
      groups: ["穀物"]
    )
    
    crop.update!(groups: ["穀物", "水田作物", "主食"])
    assert_equal ["穀物", "水田作物", "主食"], crop.groups
  end

  test "should clear groups when set to empty array" do
    crop = Crop.create!(
      name: "稲",
      user_id: @user.id,
      is_reference: false,
      groups: ["穀物", "水田作物"]
    )
    
    crop.update!(groups: [])
    assert_equal [], crop.groups
  end

  test "should include groups in to_agrr_requirement" do
    crop = Crop.create!(
      name: "rice",
      variety: "Koshihikari",
      user_id: @user.id,
      is_reference: false,
      groups: ["grain", "paddy"]
    )
    
    stage = crop.crop_stages.create!(name: "germination", order: 1)
    stage.create_temperature_requirement!(
      base_temperature: 10.0,
      optimal_min: 20.0,
      optimal_max: 30.0
    )
    stage.create_thermal_requirement!(required_gdd: 200.0)
    
    result = crop.to_agrr_requirement
    
    assert_equal ["grain", "paddy"], result['crop']['groups']
  end

  test "by_region scope should filter by region" do
    crop_jp = Crop.create!(
      name: "Rice JP",
      user_id: @user.id,
      is_reference: false,
      region: "jp"
    )
    
    crop_us = Crop.create!(
      name: "Corn US",
      user_id: @user.id,
      is_reference: false,
      region: "us"
    )
    
    crop_no_region = Crop.create!(
      name: "Wheat",
      user_id: @user.id,
      is_reference: false
    )
    
    jp_crops = Crop.by_region("jp")
    assert_includes jp_crops, crop_jp
    assert_not_includes jp_crops, crop_us
    assert_not_includes jp_crops, crop_no_region
    
    us_crops = Crop.by_region("us")
    assert_includes us_crops, crop_us
    assert_not_includes us_crops, crop_jp
  end

  test "should save crop with region" do
    crop = Crop.create!(
      name: "稲",
      user_id: @user.id,
      is_reference: false,
      region: "jp"
    )
    
    assert_equal "jp", crop.region
    crop.reload
    assert_equal "jp", crop.region
  end
end
