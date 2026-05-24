# frozen_string_literal: true

module Adapters
  module Agrr
    module Gateways
      # エントリ作物スケジュール用: AGRR CLI `optimize period` のみで栽培開始〜完了の最適期間を算出する（フォールバックなし）
      # T-035: app/services/crop_schedule/entry_agrr_optimization から adapter へ移行。
      class EntryScheduleOptimizationDaemonGateway
        ES = Domain::CultivationPlan::Interactors::EntrySchedule

        # インスタンス生成時は必ず +crop_gateway+ を渡す（テストではスタブ可）。{.call} も同様。

        # 参照作物の各ステージに同一レンジの required_gdd が載っていると、ステージ合算で非現実的な総GDDになり
        # optimize period が「計画期間内に完了不可」と返すことがある。比率は保ちつつ合計を上限に収める。
        DEFAULT_MAX_TOTAL_GDD_FOR_OPTIMIZE = 2_000.0

        # @param crop [Crop]
        # @param weather_payload [Hash] Farm#predicted_weather_data 相当
        # @param farm [Farm, nil] 気象JSONに緯度経度が無いキャッシュ等を補うため（参照農場の座標を付与）
        # @param crop_gateway [Domain::Crop::Gateways::CropGateway] ステージ行取得（CompositionRoot.crop_gateway を渡す）
        # @return [ES::WindowService::Result] 成功時は eligible: true。失敗時も同型で eligible: false と理由のみ。
        def self.call(crop:, weather_payload:, crop_gateway:, farm: nil)
          new(crop: crop, weather_payload: weather_payload, farm: farm, crop_gateway: crop_gateway).call
        end

        # WeatherPredictionInteractor の過去互換で、トップの `data` が Hash かつ内側に `data` 配列がある形を
        # フラットな AGRR 気象JSONに正規化する（正規化しないと日次配列が取れず insufficient_weather になる）。
        # @return [Hash] stringify_keys 済み
        def self.normalize_entry_weather_payload(raw)
          h = raw.is_a?(Hash) ? raw.deep_dup : {}
          h = h.deep_stringify_keys
          d = h["data"]
          if d.is_a?(Hash) && d["data"].is_a?(Array)
            inner = d.deep_stringify_keys
            h["data"] = inner["data"]
            %w[latitude longitude elevation timezone].each do |key|
              h[key] = inner[key] if h[key].blank? && inner[key].present?
            end
          end
          h
        end

        # @param requirement_hash [Hash] Crop#to_agrr_requirement 相当
        # @return [Hash] 各 stage の thermal.required_gdd をスケールしたコピー
        def self.scale_stage_gdd_for_optimize_period(requirement_hash, max_total_gdd: nil)
          Domain::CultivationPlan::Calculators::EntryScheduleStageGddScaler.call(
            requirement_hash,
            max_total_gdd: max_total_gdd
          )
        end

        def initialize(crop:, weather_payload:, crop_gateway:, farm: nil)
          @crop = crop
          @weather_payload = self.class.normalize_entry_weather_payload(weather_payload || {})
          @farm = farm
          @crop_gateway = crop_gateway
        end

        def call
          return failed_result(:disabled) unless agrr_enabled?

          eval_start, eval_end = evaluation_range
          return failed_result(:insufficient_weather) unless eval_start && eval_end && eval_end >= eval_start

          weather_for_file = weather_hash_for_agrr
          return failed_result(:insufficient_weather) if weather_for_file.blank?

          crop_requirement = self.class.scale_stage_gdd_for_optimize_period(
            Adapters::Crop::Mappers::CropAgrrRequirementMapper.build_from(@crop)
          )
          gateway = ::Adapters::Agrr::Gateways::OptimizationDaemonGateway.new
          parsed = gateway.optimize(
            crop_name: @crop.name,
            crop_variety: @crop.variety.presence || "general",
            weather_data: weather_for_file,
            field_area: 1.0,
            daily_fixed_cost: 0.01,
            evaluation_start: eval_start,
            evaluation_end: eval_end,
            crop: @crop,
            crop_requirement: crop_requirement
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
        rescue ::Adapters::Agrr::Gateways::DaemonClient::DaemonNotRunningError => e
          Rails.logger.warn("[EntryScheduleOptimizationDaemonGateway] daemon: #{e.message}")
          failed_result(:daemon_unavailable)
        rescue ::Adapters::Agrr::Gateways::BaseGatewayV2::ExecutionError, ::Adapters::Agrr::Gateways::DaemonClient::CommandExecutionError => e
          Rails.logger.warn("[EntryScheduleOptimizationDaemonGateway] execution: #{e.class}: #{e.message}")
          failed_result(:execution_failed)
        rescue ::Adapters::Agrr::Gateways::BaseGatewayV2::ParseError, ArgumentError, Date::Error, TypeError, JSON::ParserError => e
          Rails.logger.warn("[EntryScheduleOptimizationDaemonGateway] parse/args: #{e.class}: #{e.message}")
          failed_result(:invalid_response)
        rescue StandardError => e
          Rails.logger.error("[EntryScheduleOptimizationDaemonGateway] #{e.class}: #{e.message}\n#{e.backtrace&.first(8)&.join("\n")}")
          failed_result(:crop_requirement_error)
        end

        private

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

        def agrr_enabled?
          ENV["ENTRY_SCHEDULE_DISABLE_AGRR"].to_s.blank?
        end

        def weather_hash_for_agrr
          h = @weather_payload.deep_stringify_keys
          data = h["data"]
          return nil unless data.is_a?(Array) && data.any?

          core = h.slice("latitude", "longitude", "elevation", "timezone", "data")
          enrich_weather_geo!(core)
          return nil if core["latitude"].blank? || core["longitude"].blank?

          core
        end

        def enrich_weather_geo!(core)
          wl = @farm&.weather_location
          if core["latitude"].blank? && @farm&.latitude.present?
            core["latitude"] = @farm.latitude.to_f
          end
          if core["longitude"].blank? && @farm&.longitude.present?
            core["longitude"] = @farm.longitude.to_f
          end
          core["elevation"] = core["elevation"].presence || wl&.elevation&.to_f
          core["timezone"] = core["timezone"].presence || wl&.timezone
        end

        def extract_weather_end
          dates = daily_dates_from_payload
          dates.max
        end

        def extract_weather_end_safe
          extract_weather_end
        rescue StandardError
          nil
        end

        def evaluation_range
          dates = daily_dates_from_payload
          return [ nil, nil ] if dates.empty?

          data_min = dates.min
          data_max = dates.max

          today = Time.zone.today
          y = today.year
          ideal_start = Date.new(y - 1, 6, 1)
          ideal_end = Date.new(y + 1, 6, 30)

          eval_start = [ ideal_start, data_min ].max
          eval_end = [ ideal_end, data_max ].min

          return [ nil, nil ] if eval_start > eval_end

          [ eval_start, eval_end ]
        end

        def daily_dates_from_payload
          data = @weather_payload["data"] || @weather_payload[:data]
          return [] unless data.is_a?(Array)

          data.filter_map do |row|
            next unless row.is_a?(Hash)

            raw = row["time"] || row[:time] || row["date"] || row[:date]
            Date.parse(raw.to_s)
          rescue ArgumentError, TypeError
            nil
          end
        end
      end
    end
  end
end
