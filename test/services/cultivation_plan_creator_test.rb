# frozen_string_literal: true

require 'test_helper'

class CultivationPlanCreatorTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @farm = farms(:test_farm)
    @crop1 = crops(:tomato)
    @crop2 = crops(:lettuce)
  end

  test "should create cultivation plan without creating Field records" do
    initial_field_count = Field.count
    
    creator = CultivationPlanCreator.new(
      farm: @farm,
      total_area: 100.0,
      crops: [@crop1, @crop2],
      user: @user
    )
    
    result = creator.call
    
    assert result.success?
    assert_not_nil result.cultivation_plan
    assert_equal initial_field_count, Field.count, "Field records should not be created"
  end

  test "should create CultivationPlanField and CultivationPlanCrop" do
    creator = CultivationPlanCreator.new(
      farm: @farm,
      total_area: 50.0,
      crops: [@crop1],
      user: @user
    )
    
    result = creator.call
    plan = result.cultivation_plan
    
    assert_equal 1, plan.cultivation_plan_fields.count
    assert_equal 1, plan.cultivation_plan_crops.count
    
    plan_field = plan.cultivation_plan_fields.first
    plan_crop = plan.cultivation_plan_crops.first
    
    assert_equal @crop1.name, plan_crop.name
    assert_equal @crop1.variety, plan_crop.variety
    assert_equal @crop1.area_per_unit, plan_crop.area_per_unit
    assert_equal @crop1.revenue_per_area, plan_crop.revenue_per_area
    assert_equal @crop1.agrr_crop_id, plan_crop.agrr_crop_id
  end

  test "should create field_cultivations with cultivation_plan_field and cultivation_plan_crop" do
    creator = CultivationPlanCreator.new(
      farm: @farm,
      total_area: 80.0,
      crops: [@crop1],
      user: @user
    )
    
    result = creator.call
    plan = result.cultivation_plan
    fc = plan.field_cultivations.first
    
    assert_not_nil fc
    assert_not_nil fc.cultivation_plan_field
    assert_not_nil fc.cultivation_plan_crop
    assert_equal fc.area * 5.0, fc.cultivation_plan_field.daily_fixed_cost
  end

  test "should create multiple field_cultivations for multiple crops" do
    creator = CultivationPlanCreator.new(
      farm: @farm,
      total_area: 100.0,
      crops: [@crop1, @crop2],
      user: @user
    )
    
    result = creator.call
    plan = result.cultivation_plan
    
    assert_equal 2, plan.field_cultivations.count
    assert_equal 2, plan.cultivation_plan_fields.count
    assert_equal 2, plan.cultivation_plan_crops.count
    
    plan.field_cultivations.each do |fc|
      assert_nil fc.field_id
      assert_nil fc.crop_id
      assert_not_nil fc.cultivation_plan_field
      assert_not_nil fc.cultivation_plan_crop
    end
  end
end

