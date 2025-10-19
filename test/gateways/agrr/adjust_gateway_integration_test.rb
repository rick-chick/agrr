# frozen_string_literal: true

require 'test_helper'

module Agrr
  class AdjustGatewayIntegrationTest < ActiveSupport::TestCase
    setup do
      @gateway = AdjustGateway.new
    end
    
    test 'agrr optimize adjust command executes successfully with valid data' do
      # 最小限のテストデータを作成
      current_allocation = {
        optimization_result: {
          optimization_id: 'test_opt_001',
          field_schedules: [
            {
              field_id: 'field_1',
              field_name: 'テスト圃場',
              allocations: [
                {
                  allocation_id: 'alloc_001',
                  crop_id: 'tomato',
                  crop_name: 'トマト',
                  variety: 'テスト品種',
                  area_used: 100.0,
                  start_date: '2025-05-01',
                  completion_date: '2025-08-15',
                  growth_days: 106,
                  accumulated_gdd: 1500.0,
                  total_cost: 50000.0,
                  expected_revenue: 100000.0,
                  profit: 50000.0
                }
              ]
            }
          ],
          total_profit: 50000.0
        }
      }
      
      moves = [
        {
          allocation_id: 'alloc_001',
          action: 'move',
          to_field_id: 'field_1',
          to_start_date: '2025-05-15',
          to_area: 120.0
        }
      ]
      
      fields = [
        {
          field_id: 'field_1',
          name: 'テスト圃場',
          area: 200.0,
          daily_fixed_cost: 1000.0
        }
      ]
      
      crops = [
        {
          crop: {
            crop_id: 'tomato',
            name: 'トマト',
            area_per_unit: 0.25,
            variety: 'テスト品種',
            revenue_per_area: 1000.0,
            max_revenue: 200000.0,
            groups: ['Solanaceae']
          },
          stage_requirements: [
            {
              stage: { name: 'growth', order: 1 },
              temperature: {
                base_temperature: 10.0,
                optimal_min: 20.0,
                optimal_max: 30.0,
                low_stress_threshold: 15.0,
                high_stress_threshold: 35.0,
                low_limit: 5.0,
                high_limit: 40.0
              },
              gdd_requirement: 1000.0,
              duration_days: 30
            }
          ]
        }
      ]
      
      weather_data = {
        latitude: 35.6762,
        longitude: 139.6503,
        timezone: 'Asia/Tokyo',
        data: [
          {
            time: '2025-05-01',
            temperature_2m_max: 25.0,
            temperature_2m_min: 15.0,
            temperature_2m_mean: 20.0,
            precipitation_sum: 0.0
          },
          {
            time: '2025-05-02',
            temperature_2m_max: 26.0,
            temperature_2m_min: 16.0,
            temperature_2m_mean: 21.0,
            precipitation_sum: 0.0
          }
        ]
      }
      
      planning_start = Date.new(2025, 5, 1)
      planning_end = Date.new(2025, 8, 31)
      
      # agrr optimize adjustを実行
      result = @gateway.adjust(
        current_allocation: current_allocation,
        moves: moves,
        fields: fields,
        crops: crops,
        weather_data: weather_data,
        planning_start: planning_start,
        planning_end: planning_end,
        objective: 'maximize_profit'
      )
      
      # 結果の検証
      assert result.present?, 'agrr optimize adjust should return a result'
      assert result.key?(:optimization_id), 'Result should contain optimization_id'
      assert result.key?(:field_schedules), 'Result should contain field_schedules'
      assert result.key?(:total_profit), 'Result should contain total_profit'
      
      puts "✅ agrr optimize adjust executed successfully"
      puts "📊 Result: #{result.inspect}"
      
    rescue Agrr::BaseGateway::ExecutionError => e
      flunk "agrr optimize adjust failed: #{e.message}"
    end
    
    test 'agrr optimize adjust fails with invalid current_allocation format' do
      # 無効なcurrent_allocationフォーマット
      invalid_allocation = {
        optimization_result: {
          optimization_id: 'test_opt_001',
          field_schedules: [
            {
              field_id: 'field_1',
              field_name: 'テスト圃場',
              allocations: [
                {
                  allocation_id: 'alloc_001',
                  crop_id: 'tomato',
                  # area_usedフィールドが欠けている
                  start_date: '2025-05-01',
                  completion_date: '2025-08-15'
                }
              ]
            }
          ]
        }
      }
      
      moves = [
        {
          allocation_id: 'alloc_001',
          action: 'move',
          to_field_id: 'field_1',
          to_start_date: '2025-05-15'
        }
      ]
      
      fields = [
        {
          field_id: 'field_1',
          name: 'テスト圃場',
          area: 200.0,
          daily_fixed_cost: 1000.0
        }
      ]
      
      crops = [
        {
          crop: {
            crop_id: 'tomato',
            name: 'トマト',
            area_per_unit: 0.25,
            variety: 'テスト品種',
            revenue_per_area: 1000.0,
            max_revenue: 200000.0,
            groups: ['Solanaceae']
          },
          stage_requirements: [
            {
              stage: { name: 'growth', order: 1 },
              temperature: {
                base_temperature: 10.0,
                optimal_min: 20.0,
                optimal_max: 30.0,
                low_stress_threshold: 15.0,
                high_stress_threshold: 35.0,
                low_limit: 5.0,
                high_limit: 40.0
              },
              gdd_requirement: 1000.0,
              duration_days: 30
            }
          ]
        }
      ]
      
      weather_data = {
        latitude: 35.6762,
        longitude: 139.6503,
        timezone: 'Asia/Tokyo',
        data: [
          {
            time: '2025-05-01',
            temperature_2m_max: 25.0,
            temperature_2m_min: 15.0,
            temperature_2m_mean: 20.0,
            precipitation_sum: 0.0
          }
        ]
      }
      
      planning_start = Date.new(2025, 5, 1)
      planning_end = Date.new(2025, 8, 31)
      
      # エラーが発生することを期待
      assert_raises(Agrr::BaseGateway::ExecutionError) do
        @gateway.adjust(
          current_allocation: invalid_allocation,
          moves: moves,
          fields: fields,
          crops: crops,
          weather_data: weather_data,
          planning_start: planning_start,
          planning_end: planning_end,
          objective: 'maximize_profit'
        )
      end
      
      puts "✅ agrr optimize adjust correctly failed with invalid format"
    end
  end
end
