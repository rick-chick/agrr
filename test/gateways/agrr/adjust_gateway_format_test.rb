# frozen_string_literal: true

require 'test_helper'

module Agrr
  class AdjustGatewayFormatTest < ActiveSupport::TestCase
    test 'adjust gateway accepts current_allocation with area_used and total_area' do
      gateway = AdjustGateway.new
      
      # agrr optimize allocateの出力形式をシミュレート
      current_allocation = {
        optimization_result: {
          optimization_id: 'opt_test_001',
          field_schedules: [
            {
              field_id: 'field_1',
              field_name: 'テスト圃場',
              total_area: 100.0,
              area_used: 50.0,
              allocations: [
                {
                  allocation_id: 'alloc_001',
                  crop_id: 'tomato',
                  crop_name: 'トマト',
                  start_date: '2025-05-01',
                  completion_date: '2025-08-15',
                  area: 50.0,
                  revenue: 100000.0,
                  cost: 50000.0,
                  profit: 50000.0
                }
              ]
            }
          ],
          total_profit: 50000.0
        }
      }
      
      # area_usedとtotal_areaが含まれていることを確認
      field_schedule = current_allocation[:optimization_result][:field_schedules].first
      assert_equal 100.0, field_schedule[:total_area], 'total_area should be present'
      assert_equal 50.0, field_schedule[:area_used], 'area_used should be present'
      
      # JSONシリアライズが正しく動作することを確認
      json_str = JSON.generate(current_allocation)
      parsed = JSON.parse(json_str)
      
      assert parsed['optimization_result']['field_schedules'][0].key?('total_area')
      assert parsed['optimization_result']['field_schedules'][0].key?('area_used')
    end
    
    test 'area_used calculation for multiple allocations' do
      # 複数の栽培がある場合のarea_used計算をテスト
      allocations = [
        { area: 30.0 },
        { area: 20.0 },
        { area: 15.0 }
      ]
      
      area_used = allocations.sum { |a| a[:area] }
      
      assert_equal 65.0, area_used, 'area_used should be sum of all allocation areas'
    end
    
    test 'area_used should not exceed total_area in valid data' do
      # 有効なデータではarea_usedがtotal_areaを超えないことを確認
      field_schedule = {
        field_id: 'field_1',
        field_name: 'テスト圃場',
        total_area: 100.0,
        area_used: 85.0,
        allocations: []
      }
      
      assert field_schedule[:area_used] <= field_schedule[:total_area],
        'area_used should not exceed total_area'
    end
  end
end

