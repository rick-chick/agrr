# frozen_string_literal: true

module Agrr
  class AllocationGateway < BaseGatewayV2
    def allocate(fields:, crops:, weather_data:, planning_start:, planning_end:, interaction_rules: nil, objective: 'maximize_profit', max_time: nil, enable_parallel: false)
      Rails.logger.info "⚙️  [AGRR] Multi-field allocation: fields=#{fields.count}, crops=#{crops.count}"
      
      # 各種ファイルを作成
      fields_file = write_temp_file({ 'fields' => fields }, prefix: 'fields')
      crops_file = write_temp_file({ 'crops' => crops }, prefix: 'crops')
      weather_file = write_temp_file(weather_data, prefix: 'weather')
      
      # デバッグ用にファイルを保存（本番環境以外のみ）
      unless Rails.env.production?
        debug_dir = Rails.root.join('tmp/debug')
        FileUtils.mkdir_p(debug_dir)
        debug_fields_path = debug_dir.join("allocation_fields_#{Time.current.to_i}.json")
        debug_crops_path = debug_dir.join("allocation_crops_#{Time.current.to_i}.json")
        debug_weather_path = debug_dir.join("allocation_weather_#{Time.current.to_i}.json")
        FileUtils.cp(fields_file.path, debug_fields_path)
        FileUtils.cp(crops_file.path, debug_crops_path)
        FileUtils.cp(weather_file.path, debug_weather_path)
        Rails.logger.info "📁 [AGRR] Debug fields saved to: #{debug_fields_path}"
        Rails.logger.info "📁 [AGRR] Debug crops saved to: #{debug_crops_path}"
        Rails.logger.info "📁 [AGRR] Debug weather saved to: #{debug_weather_path}"
      end
      
      begin
        command_args = [
          'dummy_path', # Not used in V2
          'optimize',
          'allocate',
          '--fields-file', fields_file.path,
          '--crops-file', crops_file.path,
          '--planning-start', planning_start.to_s,
          '--planning-end', planning_end.to_s,
          '--weather-file', weather_file.path,
          '--objective', objective,
          '--format', 'json'
        ]
        
        # オプションのinteraction-rules-fileを追加
        if interaction_rules
          rules_file = write_temp_file(interaction_rules, prefix: 'interaction_rules')
          command_args += ['--interaction-rules-file', rules_file.path]
          
          unless Rails.env.production?
            debug_rules_path = debug_dir.join("allocation_rules_#{Time.current.to_i}.json")
            FileUtils.cp(rules_file.path, debug_rules_path)
            Rails.logger.info "📁 [AGRR] Debug rules saved to: #{debug_rules_path}"
          end
        end
        
        # オプションのmax-timeを追加
        if max_time
          command_args += ['--max-time', max_time.to_s]
        end
        
        # オプションのenable-parallelを追加
        if enable_parallel
          command_args += ['--enable-parallel']
        end
        
        result = execute_command(*command_args)
        
        parsed = parse_allocation_result(result)
        Rails.logger.info "✅ [AGRR] Allocation completed: fields=#{parsed[:field_schedules].count}, profit=¥#{parsed[:total_profit]}"
        
        parsed
      ensure
        fields_file.close
        fields_file.unlink
        crops_file.close
        crops_file.unlink
        weather_file.close
        weather_file.unlink
        if interaction_rules && rules_file
          rules_file.close
          rules_file.unlink
        end
      end
    end
    
    private
    
    def parse_allocation_result(raw_result)
      optimization = raw_result['optimization_result']
      summary = raw_result['summary']
      
      {
        optimization_id: optimization['optimization_id'],
        algorithm_used: optimization['algorithm_used'],
        is_optimal: optimization['is_optimal'],
        optimization_time: optimization['optimization_time'],
        total_cost: optimization['total_cost'],
        total_revenue: optimization['total_revenue'],
        total_profit: optimization['total_profit'],
        field_schedules: optimization['field_schedules'],
        crop_areas: optimization['crop_areas'],
        summary: summary,
        raw: raw_result
      }
    end
  end
end



