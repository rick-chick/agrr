# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # エントリ作物スケジュール: 気象正規化・GDD スケール・ステージ取得のうえ AGRR optimize period を呼ぶ。
      class EntryScheduleOptimizeInteractor
        ES = EntrySchedule

        # @param crop [Object] name / variety / id を持つ参照作物（エッジで AR）
        # @param weather_payload [Hash]
        # @param farm [Object, nil] 気象 JSON の緯度経度補完用
        # @param crop_gateway [Domain::Crop::Gateways::CropGateway]
        # @param crop_agrr_requirement_builder [Domain::Shared::Ports::CropAgrrRequirementBuilderPort]
        # @param entry_schedule_optimization_gateway [Domain::CultivationPlan::Gateways::EntryScheduleOptimizationGateway]
        # @param clock [#today]
        # @param logger [#warn, #error, nil]
        # @param agrr_enabled [Boolean]
        def initialize(
          crop:,
          weather_payload:,
          crop_gateway:,
          crop_agrr_requirement_builder:,
          entry_schedule_optimization_gateway:,
          clock:,
          farm: nil,
          logger: nil,
          agrr_enabled: true
        )
          @crop = crop
          @weather_payload = Normalizers::EntryScheduleWeatherPayloadNormalizer.call(weather_payload)
          @farm = farm
          @crop_gateway = crop_gateway
          @crop_agrr_requirement_builder = crop_agrr_requirement_builder
          @entry_schedule_optimization_gateway = entry_schedule_optimization_gateway
          @clock = clock
          @logger = logger
          @agrr_enabled = agrr_enabled
        end

        def self.call(**kwargs)
          new(**kwargs).call
        end

        def call
          return failed_result(:disabled) unless @agrr_enabled

          eval_start, eval_end = evaluation_range
          return failed_result(:insufficient_weather) unless eval_start && eval_end && eval_end >= eval_start

          weather_for_file = weather_hash_for_agrr
          return failed_result(:insufficient_weather) if weather_for_file.blank?

          crop_requirement = Calculators::EntryScheduleStageGddScaler.call(
            @crop_agrr_requirement_builder.build_from(@crop)
          )
          parsed = @entry_schedule_optimization_gateway.optimize_period(
            crop_name: @crop.name,
            crop_variety: crop_variety,
            weather_data: weather_for_file,
            evaluation_start: eval_start,
            evaluation_end: eval_end,
            crop_requirement: crop_requirement,
            crop: @crop
          )

          start_d = parsed[:start_date]
          end_d = parsed[:completion_date]
          return failed_result(:invalid_response) unless start_d.is_a?(Date) && end_d.is_a?(Date) && end_d >= start_d

          stage_rows = @crop_gateway.entry_schedule_ordered_stage_rows(crop_id: @crop.id)
          sow_st = ES::StageRoleResolver.sowing_stage(stage_rows)
          tr_st = ES::StageRoleResolver.transplant_stage(stage_rows)
          daily_count = Array(weather_for_file["data"]).size

          ES::WindowService::Result.new(
            eligible: true,
            sowing_windows: [ { start_date: start_d, end_date: end_d } ],
            transplant_windows: [ { start_date: start_d, end_date: end_d } ],
            reason_parts: {
              source: "agrr_optimize_period",
              rule: "agrr_optimize_period",
              optimal_start_date: start_d.iso8601,
              completion_date: end_d.iso8601,
              growth_days: parsed[:days],
              gdd: parsed[:gdd],
              total_cost: parsed[:cost],
              days_evaluated: daily_count,
              sowing_stage_name: sow_st&.name,
              transplant_stage_name: tr_st&.name
            },
            sowing_stage_id: sow_st&.id,
            transplant_stage_id: tr_st&.id,
            weather_end_date: extract_weather_end
          )
        rescue Errors::EntryScheduleOptimizationError => e
          log_warn("optimize: #{e.message}")
          failed_result(e.error_key)
        rescue ArgumentError, Date::Error, TypeError => e
          log_warn("parse/args: #{e.class}: #{e.message}")
          failed_result(:invalid_response)
        rescue StandardError => e
          log_error("#{e.class}: #{e.message}")
          failed_result(:crop_requirement_error)
        end

        private

        def crop_variety
          variety = @crop.respond_to?(:variety) ? @crop.variety : nil
          Domain::Shared.present?(variety) ? variety : "general"
        end

        def failed_result(error_key)
          ES::WindowService::Result.new(
            eligible: false,
            sowing_windows: [],
            transplant_windows: [],
            reason_parts: {
              source: "agrr_failed",
              error_key: error_key.to_s
            },
            sowing_stage_id: nil,
            transplant_stage_id: nil,
            weather_end_date: extract_weather_end_safe
          )
        end

        def weather_hash_for_agrr
          h = Domain::Shared.stringify_keys(@weather_payload)
          data = h["data"]
          return nil unless data.is_a?(Array) && data.any?

          core = h.slice("latitude", "longitude", "elevation", "timezone", "data")
          enrich_weather_geo!(core)
          return nil if Domain::Shared.blank?(core["latitude"]) || Domain::Shared.blank?(core["longitude"])

          core
        end

        def enrich_weather_geo!(core)
          return if @farm.nil?

          wl = @farm.respond_to?(:weather_location) ? @farm.weather_location : nil
          if Domain::Shared.blank?(core["latitude"]) && @farm.respond_to?(:latitude) && Domain::Shared.present?(@farm.latitude)
            core["latitude"] = @farm.latitude.to_f
          end
          if Domain::Shared.blank?(core["longitude"]) && @farm.respond_to?(:longitude) && Domain::Shared.present?(@farm.longitude)
            core["longitude"] = @farm.longitude.to_f
          end
          if wl && Domain::Shared.blank?(core["elevation"]) && wl.respond_to?(:elevation) && Domain::Shared.present?(wl.elevation)
            core["elevation"] = wl.elevation.to_f
          end
          if wl && Domain::Shared.blank?(core["timezone"]) && wl.respond_to?(:timezone) && Domain::Shared.present?(wl.timezone)
            core["timezone"] = wl.timezone
          end
        end

        def evaluation_range
          dates = daily_dates_from_payload
          return [ nil, nil ] if dates.empty?

          data_min = dates.min
          data_max = dates.max

          today = @clock.today
          y = today.year
          ideal_start = Date.new(y - 1, 6, 1)
          ideal_end = Date.new(y + 1, 6, 30)

          eval_start = [ ideal_start, data_min ].max
          eval_end = [ ideal_end, data_max ].min

          return [ nil, nil ] if eval_start > eval_end

          [ eval_start, eval_end ]
        end

        def daily_dates_from_payload
          data = @weather_payload["data"]
          return [] unless data.is_a?(Array)

          data.filter_map do |row|
            next unless row.is_a?(Hash)

            raw = row["time"] || row[:time] || row["date"] || row[:date]
            Date.parse(raw.to_s)
          rescue ArgumentError, TypeError
            nil
          end
        end

        def extract_weather_end
          daily_dates_from_payload.max
        end

        def extract_weather_end_safe
          extract_weather_end
        rescue StandardError
          nil
        end

        def log_warn(message)
          @logger&.warn("[EntryScheduleOptimizeInteractor] #{message}")
        end

        def log_error(message)
          @logger&.error("[EntryScheduleOptimizeInteractor] #{message}")
        end
      end
    end
  end
end
