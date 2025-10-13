# frozen_string_literal: true

module Agrr
  class OptimizationGateway < BaseGateway
    def optimize(crop_name:, variety:, weather_data:, field_area:, daily_fixed_cost:, evaluation_start:, evaluation_end:)
      Rails.logger.info "⚙️  [AGRR] Optimizing: crop=#{crop_name}, variety=#{variety}"
      
      field_config = build_field_config(field_area, daily_fixed_cost)
      Rails.logger.info "📊 [AGRR] Field config: #{field_config.to_json}"
      
      weather_file = write_temp_file(weather_data, prefix: 'weather')
      field_file = write_temp_file(field_config, prefix: 'field')
      
      # デバッグ用にファイルを保存
      debug_dir = Rails.root.join('tmp/debug')
      FileUtils.mkdir_p(debug_dir)
      debug_weather_path = debug_dir.join("optimization_weather_#{Time.current.to_i}.json")
      debug_field_path = debug_dir.join("optimization_field_#{Time.current.to_i}.json")
      FileUtils.cp(weather_file.path, debug_weather_path)
      FileUtils.cp(field_file.path, debug_field_path)
      Rails.logger.info "📁 [AGRR] Debug weather saved to: #{debug_weather_path}"
      Rails.logger.info "📁 [AGRR] Debug field saved to: #{debug_field_path}"
      
      begin
        result = execute_command(
          agrr_path,
          'optimize-period',
          'optimize',
          '--crop', crop_name,
          '--variety', variety.to_s,
          '--evaluation-start', evaluation_start.to_s,
          '--evaluation-end', evaluation_end.to_s,
          '--weather-file', weather_file.path,
          '--field-config', field_file.path,
          '--format', 'json'
        )
        
        parsed = parse_optimization_result(result)
        Rails.logger.info "✅ [AGRR] Optimization completed: start=#{parsed[:start_date]}, days=#{parsed[:days]}"
        
        parsed
      ensure
        weather_file.close
        weather_file.unlink
        field_file.close
        field_file.unlink
      end
    end
    
    private
    
    def build_field_config(area, daily_fixed_cost)
      {
        'name' => "Field-#{SecureRandom.hex(4)}",
        'field_id' => SecureRandom.uuid,
        'area' => area,
        'daily_fixed_cost' => daily_fixed_cost
      }
    end
    
    def parse_optimization_result(raw_result)
      optimal = raw_result['optimal_periods']&.first || raw_result
      
      {
        start_date: Date.parse(optimal['optimal_start_date']),
        completion_date: Date.parse(optimal['completion_date']),
        days: optimal['growth_days'],
        cost: optimal['total_cost'],
        gdd: optimal['gdd'],
        raw: raw_result
      }
    end
  end
end

