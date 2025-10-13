# frozen_string_literal: true

module Api
  module V1
    module PublicPlans
      class FieldCultivationsController < ApplicationController
        skip_before_action :authenticate_user!
        
        # GET /api/v1/public_plans/field_cultivations/:id
        def show
          field_cultivation = FieldCultivation.find(params[:id])
          
          render json: build_detail_response(field_cultivation)
        rescue ActiveRecord::RecordNotFound
          render json: { error: 'Field cultivation not found' }, status: :not_found
        end
        
        private
        
        def build_detail_response(fc)
          {
            id: fc.id,
            field_name: fc.field_display_name,
            crop_name: fc.crop_display_name,
            area: fc.area,
            start_date: fc.start_date&.to_s,
            completion_date: fc.completion_date&.to_s,
            cultivation_days: fc.cultivation_days,
            gdd: fc.optimization_result&.dig('gdd'),
            estimated_cost: fc.estimated_cost,
            stages: build_stages_data(fc),
            weather_data: build_weather_data(fc),
            temperature_stats: build_temperature_stats(fc),
            gdd_info: build_gdd_info(fc),
            gdd_data: build_gdd_chart_data(fc),
            optimal_temperature_range: build_optimal_temp_range(fc)
          }
        end
        
        def build_stages_data(fc)
          raw_stages = fc.optimization_result&.dig('raw', 'stages') || []
          
          raw_stages.map do |stage|
            {
              name: stage['name'] || stage[:name],
              start_date: stage['start_date'] || stage[:start_date],
              end_date: stage['end_date'] || stage[:end_date],
              days: stage['days'] || stage[:days] || 0,
              gdd_required: stage['gdd_required'] || stage[:gdd_required] || 0,
              gdd_actual: stage['gdd_actual'] || stage[:gdd_actual] || 0,
              gdd_achieved: (stage['gdd_actual'] || stage[:gdd_actual] || 0) >= (stage['gdd_required'] || stage[:gdd_required] || 0),
              avg_temp: stage['avg_temp'] || stage[:avg_temp] || 0,
              optimal_temp_min: stage['optimal_temp_min'] || stage[:optimal_temp_min] || 0,
              optimal_temp_max: stage['optimal_temp_max'] || stage[:optimal_temp_max] || 0,
              risks: stage['risks'] || stage[:risks] || []
            }
          end
        end
        
        def build_weather_data(fc)
          return [] unless fc.start_date && fc.completion_date
          
          farm = fc.farm
          weather_location = WeatherLocation.find_by(
            latitude: farm.latitude,
            longitude: farm.longitude
          )
          
          return [] unless weather_location
          
          weather_data = weather_location.weather_data
            .where(date: fc.start_date..fc.completion_date)
            .order(:date)
          
          weather_data.map do |datum|
            {
              date: datum.date.to_s,
              temperature_max: datum.temperature_max,
              temperature_min: datum.temperature_min,
              temperature_mean: datum.temperature_mean
            }
          end
        end
        
        def build_temperature_stats(fc)
          return nil unless fc.start_date && fc.completion_date
          
          weather_data = get_weather_data(fc)
          return nil if weather_data.empty?
          
          # 最適温度範囲（仮の値、実際はcrop_stagesから取得）
          optimal_min = 15.0
          optimal_max = 30.0
          high_temp_threshold = 35.0
          low_temp_threshold = 10.0
          
          total_days = weather_data.count
          optimal_days = weather_data.count { |d| d.temperature_mean.between?(optimal_min, optimal_max) }
          high_temp_days = weather_data.count { |d| d.temperature_max > high_temp_threshold }
          low_temp_days = weather_data.count { |d| d.temperature_min < low_temp_threshold }
          
          {
            total_days: total_days,
            optimal_days: optimal_days,
            optimal_percentage: total_days > 0 ? ((optimal_days.to_f / total_days) * 100).round(1) : 0,
            high_temp_days: high_temp_days,
            low_temp_days: low_temp_days
          }
        end
        
        def build_gdd_info(fc)
          gdd_raw = fc.optimization_result&.dig('gdd')
          return nil unless gdd_raw
          
          target_gdd = fc.optimization_result&.dig('raw', 'target_gdd') || gdd_raw
          actual_gdd = gdd_raw
          percentage = ((actual_gdd - target_gdd) / target_gdd * 100).round(1)
          
          # 達成日を計算（簡易版）
          achievement_date = fc.completion_date
          
          {
            target: target_gdd,
            actual: actual_gdd,
            percentage: percentage,
            achievement_date: achievement_date&.to_s
          }
        end
        
        def build_gdd_chart_data(fc)
          return [] unless fc.start_date && fc.completion_date
          
          weather_data = get_weather_data(fc)
          return [] if weather_data.empty?
          
          base_temp = 10.0 # ベース温度（仮）
          target_gdd = fc.optimization_result&.dig('gdd') || 0
          accumulated = 0.0
          
          weather_data.map do |datum|
            daily_gdd = [datum.temperature_mean - base_temp, 0].max
            accumulated += daily_gdd
            
            {
              date: datum.date.to_s,
              accumulated_gdd: accumulated.round(1),
              target_gdd: target_gdd
            }
          end
        end
        
        def build_optimal_temp_range(fc)
          # 作物の最適温度範囲を取得（仮の値）
          # 実際はcrop_stagesから取得
          {
            min: 15.0,
            max: 30.0
          }
        end
        
        def get_weather_data(fc)
          return [] unless fc.start_date && fc.completion_date
          
          farm = fc.farm
          weather_location = WeatherLocation.find_by(
            latitude: farm.latitude,
            longitude: farm.longitude
          )
          
          return [] unless weather_location
          
          weather_location.weather_data
            .where(date: fc.start_date..fc.completion_date)
            .order(:date)
        end
      end
    end
  end
end

