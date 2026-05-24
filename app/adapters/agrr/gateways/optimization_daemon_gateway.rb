# frozen_string_literal: true

module Adapters
  module Agrr
    module Gateways
      class OptimizationDaemonGateway < BaseGatewayV2
        def optimize(crop_name:, crop_variety:, weather_data:, field_area:, daily_fixed_cost:, evaluation_start:, evaluation_end:, crop_requirement:, interaction_rules: nil, crop: nil)
          Rails.logger.info "⚙️  [AGRR] Optimizing: crop=#{crop_name}, variety=#{crop_variety}"

          unless crop_requirement
            raise ArgumentError, "crop_requirement is required (build via CropAgrrRequirementBuilderPort at the edge)"
          end

          field_config = build_field_config(field_area, daily_fixed_cost)
          Rails.logger.info "📊 [AGRR] Field config: #{field_config.to_json}"

          weather_file = write_temp_file(weather_data, prefix: "weather")
          field_file = write_temp_file(field_config, prefix: "field")

          crop_file = write_temp_file(crop_requirement, prefix: "crop_profile")
          Rails.logger.info "📝 [AGRR] Crop requirement: #{crop_requirement.to_json}"

          # デバッグ用にファイルを保存（本番環境以外のみ）
          unless Rails.env.production?
            debug_dir = Rails.root.join("tmp/debug")
            FileUtils.mkdir_p(debug_dir)
            debug_weather_path = debug_dir.join("optimization_weather_#{Time.current.to_i}.json")
            debug_field_path = debug_dir.join("optimization_field_#{Time.current.to_i}.json")
            debug_crop_path = debug_dir.join("optimization_crop_#{Time.current.to_i}.json")
            FileUtils.cp(weather_file.path, debug_weather_path)
            FileUtils.cp(field_file.path, debug_field_path)
            FileUtils.cp(crop_file.path, debug_crop_path)
            Rails.logger.info "📁 [AGRR] Debug weather saved to: #{debug_weather_path}"
            Rails.logger.info "📁 [AGRR] Debug field saved to: #{debug_field_path}"
            Rails.logger.info "📁 [AGRR] Debug crop saved to: #{debug_crop_path}"
          end

          begin
            command_args = [
              "dummy_path", # Not used in V2
              "optimize",
              "period",
              "--crop-file", crop_file.path,
              "--evaluation-start", evaluation_start.to_s,
              "--evaluation-end", evaluation_end.to_s,
              "--weather-file", weather_file.path,
              "--field-file", field_file.path,
              "--format", "json"
            ]

            # オプションのinteraction-rules-fileを追加
            if interaction_rules
              rules_file = write_temp_file(interaction_rules, prefix: "interaction_rules")
              command_args += [ "--interaction-rules-file", rules_file.path ]

              unless Rails.env.production?
                debug_rules_path = debug_dir.join("optimization_rules_#{Time.current.to_i}.json")
                FileUtils.cp(rules_file.path, debug_rules_path)
                Rails.logger.info "📁 [AGRR] Debug rules saved to: #{debug_rules_path}"
              end
            end

            result = execute_command(*command_args)

            parsed = parse_optimization_result(result)
            Rails.logger.info "✅ [AGRR] Optimization completed: start=#{parsed[:start_date]}, days=#{parsed[:days]}"

            parsed
          ensure
            weather_file.close
            weather_file.unlink
            field_file.close
            field_file.unlink
            crop_file.close
            crop_file.unlink
            if interaction_rules && rules_file
              rules_file.close
              rules_file.unlink
            end
          end
        end

        private

        def build_field_config(area, daily_fixed_cost)
          {
            "name" => "Field-#{SecureRandom.hex(4)}",
            "field_id" => SecureRandom.uuid,
            "area" => area,
            "daily_fixed_cost" => daily_fixed_cost
          }
        end

        def parse_optimization_result(raw_result)
          raise ParseError, "optimize period: response is not a Hash" unless raw_result.is_a?(Hash)

          optimal = raw_result["optimal_periods"]&.first
          optimal ||= raw_result["optimalPeriods"]&.first
          if optimal.nil? && (raw_result["optimal_start_date"].present? || raw_result["optimalStartDate"].present?)
            optimal = raw_result
          end
          raise ParseError, "optimize period: missing optimal period" unless optimal.is_a?(Hash)

          start_s = optimal["optimal_start_date"].presence || optimal["optimalStartDate"].presence
          end_s = optimal["completion_date"].presence || optimal["completionDate"].presence
          raise ParseError, "optimize period: missing start/end (keys: #{optimal.keys.first(12).join(',')})" if start_s.blank? || end_s.blank?

          {
            start_date: Date.parse(start_s.to_s),
            completion_date: Date.parse(end_s.to_s),
            days: optimal["growth_days"] || optimal["growthDays"],
            cost: optimal["total_cost"] || optimal["totalCost"],
            gdd: optimal["gdd"],
            raw: raw_result
          }
        end
      end
    end
  end
end
