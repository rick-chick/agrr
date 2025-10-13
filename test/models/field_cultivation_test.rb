# frozen_string_literal: true

require 'test_helper'

class FieldCultivationTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @farm = farms(:test_farm)
    @crop = crops(:tomato)
    @cultivation_plan = CultivationPlan.create!(
      farm: @farm,
      user: @user,
      total_area: 100.0
    )
  end

  test "should create field_cultivation with cultivation_plan_field and cultivation_plan_crop" do
    plan_field = CultivationPlanField.create!(
      cultivation_plan: @cultivation_plan,
      name: 'トマト - 圃場1',
      area: 50.0,
      daily_fixed_cost: 250.0
    )
    
    plan_crop = CultivationPlanCrop.create!(
      cultivation_plan: @cultivation_plan,
      name: 'トマト',
      variety: '桃太郎',
      area_per_unit: 1.0,
      revenue_per_area: 1000.0,
      agrr_crop_id: 'tomato'
    )
    
    fc = FieldCultivation.new(
      cultivation_plan: @cultivation_plan,
      cultivation_plan_field: plan_field,
      cultivation_plan_crop: plan_crop,
      area: 50.0
    )
    
    assert fc.valid?, "FieldCultivation should be valid with cultivation_plan_field and cultivation_plan_crop"
    assert fc.save
    assert_equal plan_field, fc.cultivation_plan_field
    assert_equal plan_crop, fc.cultivation_plan_crop
  end

  test "crop_display_name should return cultivation_plan_crop name" do
    plan_crop = CultivationPlanCrop.create!(
      cultivation_plan: @cultivation_plan,
      name: 'キャベツ',
      variety: '春キャベツ'
    )
    
    plan_field = CultivationPlanField.create!(
      cultivation_plan: @cultivation_plan,
      name: '圃場A',
      area: 30.0
    )
    
    fc = FieldCultivation.create!(
      cultivation_plan: @cultivation_plan,
      cultivation_plan_field: plan_field,
      cultivation_plan_crop: plan_crop,
      area: 30.0
    )
    
    assert_equal 'キャベツ（春キャベツ）', fc.crop_display_name
  end

  test "field_display_name should return cultivation_plan_field name" do
    plan_field = CultivationPlanField.create!(
      cultivation_plan: @cultivation_plan,
      name: '圃場A',
      area: 30.0
    )
    
    plan_crop = CultivationPlanCrop.create!(
      cultivation_plan: @cultivation_plan,
      name: 'レタス'
    )
    
    fc = FieldCultivation.create!(
      cultivation_plan: @cultivation_plan,
      cultivation_plan_field: plan_field,
      cultivation_plan_crop: plan_crop,
      area: 30.0
    )
    
    assert_equal '圃場A', fc.field_display_name
  end

  test "crop_info should return cultivation_plan_crop values" do
    plan_crop = CultivationPlanCrop.create!(
      cultivation_plan: @cultivation_plan,
      name: 'レタス',
      variety: 'サラダ菜',
      area_per_unit: 0.5,
      revenue_per_area: 800.0,
      agrr_crop_id: 'lettuce'
    )
    
    plan_field = CultivationPlanField.create!(
      cultivation_plan: @cultivation_plan,
      name: '圃場B',
      area: 20.0
    )
    
    fc = FieldCultivation.create!(
      cultivation_plan: @cultivation_plan,
      cultivation_plan_field: plan_field,
      cultivation_plan_crop: plan_crop,
      area: 20.0
    )
    
    info = fc.crop_info
    assert_equal 'レタス', info[:name]
    assert_equal 'サラダ菜', info[:variety]
    assert_equal 0.5, info[:area_per_unit]
    assert_equal 800.0, info[:revenue_per_area]
    assert_equal 'lettuce', info[:agrr_id]
  end

  test "field_info should return cultivation_plan_field values" do
    plan_field = CultivationPlanField.create!(
      cultivation_plan: @cultivation_plan,
      name: '圃場B',
      area: 40.0,
      daily_fixed_cost: 200.0
    )
    
    plan_crop = CultivationPlanCrop.create!(
      cultivation_plan: @cultivation_plan,
      name: 'ニンジン'
    )
    
    fc = FieldCultivation.create!(
      cultivation_plan: @cultivation_plan,
      cultivation_plan_field: plan_field,
      cultivation_plan_crop: plan_crop,
      area: 40.0
    )
    
    info = fc.field_info
    assert_equal '圃場B', info[:name]
    assert_equal 40.0, info[:area]
    assert_equal 200.0, info[:daily_fixed_cost]
  end
end

