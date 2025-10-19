# frozen_string_literal: true

require 'test_helper'

class AdjustAllocationFormatTest < ActiveSupport::TestCase
  setup do
    @cultivation_plan = cultivation_plans(:one)
    @field = cultivation_plan_fields(:one)
    @crop = cultivation_plan_crops(:one)
    
    # テスト用の栽培データを作成
    @cultivation1 = FieldCultivation.create!(
      cultivation_plan: @cultivation_plan,
      cultivation_plan_field: @field,
      cultivation_plan_crop: @crop,
      start_date: Date.new(2025, 5, 1),
      completion_date: Date.new(2025, 8, 15),
      area: 30.0,
      optimization_result: {
        'revenue' => 60000.0,
        'cost' => 30000.0,
        'profit' => 30000.0
      }
    )
    
    @cultivation2 = FieldCultivation.create!(
      cultivation_plan: @cultivation_plan,
      cultivation_plan_field: @field,
      cultivation_plan_crop: @crop,
      start_date: Date.new(2025, 9, 1),
      completion_date: Date.new(2025, 10, 15),
      area: 20.0,
      optimization_result: {
        'revenue' => 40000.0,
        'cost' => 20000.0,
        'profit' => 20000.0
      }
    )
  end
  
  test 'build_current_allocation produces correct format with area_used and total_area' do
    # Controllerのprivateメソッドをテスト
    controller = Api::V1::PublicPlans::CultivationPlansController.new
    
    result = controller.send(:build_current_allocation, @cultivation_plan)
    
    # 基本構造を確認
    assert result.key?(:optimization_result)
    assert result[:optimization_result].key?(:field_schedules)
    
    field_schedules = result[:optimization_result][:field_schedules]
    assert field_schedules.length > 0, 'Should have at least one field schedule'
    
    field_schedule = field_schedules.first
    
    # 必須フィールドが存在することを確認
    assert field_schedule.key?(:field_id), 'field_id is required'
    assert field_schedule.key?(:field_name), 'field_name is required'
    assert field_schedule.key?(:total_area), 'total_area is required'
    assert field_schedule.key?(:area_used), 'area_used is required'
    assert field_schedule.key?(:allocations), 'allocations is required'
    
    # area_usedが正しく計算されていることを確認
    expected_area_used = 30.0 + 20.0  # cultivation1 + cultivation2
    assert_equal expected_area_used, field_schedule[:area_used],
      "area_used should be sum of cultivation areas (#{expected_area_used})"
    
    # total_areaが圃場の面積と一致することを確認
    assert_equal @field.area, field_schedule[:total_area],
      'total_area should match field area'
    
    # allocationsが正しい形式であることを確認
    allocations = field_schedule[:allocations]
    assert_equal 2, allocations.length, 'Should have 2 allocations'
    
    allocation = allocations.first
    assert allocation.key?(:allocation_id)
    assert allocation.key?(:crop_id)
    assert allocation.key?(:crop_name)
    assert allocation.key?(:start_date)
    assert allocation.key?(:completion_date)
    assert allocation.key?(:area)
    assert allocation.key?(:revenue)
    assert allocation.key?(:cost)
    assert allocation.key?(:profit)
  end
  
  test 'current_allocation format is compatible with agrr optimize adjust command' do
    controller = Api::V1::PublicPlans::CultivationPlansController.new
    result = controller.send(:build_current_allocation, @cultivation_plan)
    
    # JSONシリアライズして、agrrコマンドが期待する形式になっていることを確認
    json_str = JSON.generate(result)
    parsed = JSON.parse(json_str)
    
    # agrr optimize adjustが期待する構造
    assert parsed.key?('optimization_result')
    assert parsed['optimization_result'].key?('field_schedules')
    
    field_schedule = parsed['optimization_result']['field_schedules'].first
    
    # agrr optimize adjustが必要とするフィールド
    assert field_schedule.key?('field_id'), 'agrr requires field_id'
    assert field_schedule.key?('field_name'), 'agrr requires field_name'
    assert field_schedule.key?('total_area'), 'agrr requires total_area'
    assert field_schedule.key?('area_used'), 'agrr requires area_used'
    assert field_schedule.key?('allocations'), 'agrr requires allocations'
    
    allocation = field_schedule['allocations'].first
    assert allocation.key?('allocation_id'), 'agrr requires allocation_id'
    assert allocation.key?('crop_id'), 'agrr requires crop_id'
    assert allocation.key?('start_date'), 'agrr requires start_date'
    assert allocation.key?('completion_date'), 'agrr requires completion_date'
    assert allocation.key?('area'), 'agrr requires area'
  end
end

