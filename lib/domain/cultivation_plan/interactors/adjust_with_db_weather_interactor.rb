# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # DB 上の天気で agrr adjust を回す主導線（旧 AgrrOptimization#adjust_with_db_weather）。
      class AdjustWithDbWeatherInteractor
        WEATHER_PHASE_EXCEPTIONS = [
          Domain::WeatherData::Interactors::WeatherPredictionInteractor::WeatherDataNotFoundError,
          Domain::WeatherData::Interactors::WeatherPredictionInteractor::InsufficientPredictionDataError,
          ArgumentError,
          Domain::Shared::Exceptions::RecordNotFound,
          Net::OpenTimeout,
          Net::ReadTimeout,
          Net::WriteTimeout,
          SocketError,
          SystemCallError,
          IOError,
          JSON::ParserError,
          TypeError,
          NoMethodError
        ].freeze

        GENERAL_PERIOD_EXCEPTIONS = [ Date::Error, TypeError, NoMethodError, RangeError, ZeroDivisionError ].freeze

        def initialize(
          logger:,
          translator:,
          clock:,
          plan_gateway:,
          weather_prediction_interactor_factory:,
          agrr_adjust_gateway:,
          save_adjusted_gateway:,
          optimization_events_gateway:,
          debug_dump:
        )
          @logger = logger
          @translator = translator
          @clock = clock
          @plan_gateway = plan_gateway
          @weather_prediction_interactor_factory = weather_prediction_interactor_factory
          @agrr_adjust_gateway = agrr_adjust_gateway
          @save_adjusted_gateway = save_adjusted_gateway
          @optimization_events_gateway = optimization_events_gateway
          @debug_dump = debug_dump
        end

        # @param plan_id [Integer]
        # @param moves [Array<Hash>]
        # @return [Hash]
        def call(plan_id:, moves:)
          perf_start = @clock.now
          @logger.info "⏱️ [PERF] adjust_with_db_weather() 開始: #{perf_start}"

          if moves.empty?
            @logger.info "ℹ️ [Adjust] 移動指示が空のため調整をスキップします"
            return {
              success: true,
              message: "調整不要（移動指示なし）"
            }
          end

          @plan_gateway.begin_adjust_session!(plan_id)

          perf_db_load = @clock.now
          @logger.info "⏱️ [PERF] DB読み込み完了: #{((perf_db_load - perf_start) * 1000).round(2)}ms"

          perf_before_allocation = @clock.now
          current_allocation = @plan_gateway.build_current_allocation(exclude_ids: [])
          perf_after_allocation = @clock.now
          @logger.info "⏱️ [PERF] 割り当てデータ構築: #{((perf_after_allocation - perf_before_allocation) * 1000).round(2)}ms"

          fields = @plan_gateway.build_fields_config
          perf_after_fields = @clock.now
          @logger.info "⏱️ [PERF] 圃場設定構築: #{((perf_after_fields - perf_after_allocation) * 1000).round(2)}ms"

          crops = @plan_gateway.build_crops_config
          perf_after_crops = @clock.now
          @logger.info "⏱️ [PERF] 作物設定構築: #{((perf_after_crops - perf_after_fields) * 1000).round(2)}ms"

          @debug_dump&.call(
            current_allocation: current_allocation,
            moves: moves,
            fields: fields,
            crops: crops
          )

          if @plan_gateway.farm_without_weather_location?
            return {
              success: false,
              message: @translator.translate("api.errors.no_weather_data"),
              status: :not_found
            }
          end

          effective_planning_start, effective_planning_end, period_failure =
            resolve_effective_planning_period(current_allocation, moves)
          return period_failure if period_failure

          weather_data, weather_failure = fetch_and_merge_weather_data(
            effective_planning_end,
            effective_planning_start
          )
          return weather_failure if weather_failure

          weather_data = normalize_nested_weather_data(weather_data)

          perf_before_rules = @clock.now
          interaction_rules = @plan_gateway.build_interaction_rules
          perf_after_rules = @clock.now
          @logger.info "⏱️ [PERF] 交互作用ルール構築: #{((perf_after_rules - perf_before_rules) * 1000).round(2)}ms"

          effective_planning_start, effective_planning_end, period_failure_after =
            resolve_effective_planning_period(current_allocation, moves)
          return period_failure_after if period_failure_after

          effective_planning_start = clamp_planning_start_to_weather!(
            weather_data,
            effective_planning_start
          )

          run_adjust_and_persist(
            plan_id: plan_id,
            moves: moves,
            fields: fields,
            crops: crops,
            weather_data: weather_data,
            interaction_rules: interaction_rules,
            effective_planning_start: effective_planning_start,
            effective_planning_end: effective_planning_end,
            current_allocation: current_allocation,
            perf_start: perf_start,
            perf_db_load: perf_db_load
          )
        ensure
          @plan_gateway.end_adjust_session!
        end

        private

        def resolve_effective_planning_period(current_allocation, moves)
          start_d, end_d = @plan_gateway.effective_planning_period(
            current_allocation: current_allocation,
            moves: moves,
            as_of: @clock.today
          )
          [ start_d, end_d, nil ]
        rescue Domain::CultivationPlan::Errors::EffectivePlanningPeriodInvalidDateError => e
          detail_message = effective_period_invalid_detail(e)
          @logger.error "❌ [Adjust] Invalid date format in planning period calculation: #{detail_message}"
          [
            nil,
            nil,
            {
              success: false,
              message: @translator.translate("api.errors.common.invalid_date_format", message: detail_message),
              status: :bad_request
            }
          ]
        rescue ArgumentError => e
          @logger.error "❌ [Adjust] Invalid date format in planning period calculation: #{e.message}"
          [
            nil,
            nil,
            {
              success: false,
              message: @translator.translate("api.errors.common.invalid_date_format", message: e.message),
              status: :bad_request
            }
          ]
        rescue *GENERAL_PERIOD_EXCEPTIONS => e
          @logger.error "❌ [Adjust] Failed to calculate planning period: #{e.class.name}: #{e.message}"
          @logger.error "❌ [Adjust] Backtrace: #{e.backtrace.first(10).join("\n")}"
          [
            nil,
            nil,
            {
              success: false,
              message: @translator.translate("api.errors.optimization.calculate_period_failed", message: e.message),
              status: :internal_server_error
            }
          ]
        end

        def effective_period_invalid_detail(error)
          case error.field
          when :start_date
            @translator.translate(
              "controllers.agrr_optimization.errors.start_date_invalid",
              value: error.raw_value.inspect,
              allocation_id: error.allocation_id
            )
          when :completion_date
            @translator.translate(
              "controllers.agrr_optimization.errors.completion_date_invalid",
              value: error.raw_value.inspect,
              allocation_id: error.allocation_id
            )
          when :to_start_date
            "不正な移動先開始日付形式です: #{error.raw_value.inspect} (move: #{error.move.inspect})"
          else
            error.message
          end
        end

        def fetch_and_merge_weather_data(effective_planning_end, effective_planning_start)
          wl_farm = @plan_gateway.weather_prediction_association_records
          weather_location = wl_farm[:weather_location]
          farm = wl_farm[:farm]

          unless weather_location
            raise Domain::WeatherData::Interactors::WeatherPredictionInteractor::WeatherDataNotFoundError,
                  "気象データがありません。農場にWeatherLocationが設定されていません。"
          end

          weather_prediction_service = @weather_prediction_interactor_factory.call(
            weather_location: weather_location,
            farm: farm
          )

          plan_weather_dto = @plan_gateway.cultivation_plan_weather_dto

          existing_prediction = weather_prediction_service.get_existing_prediction(
            target_end_date: effective_planning_end,
            cultivation_plan_weather: plan_weather_dto
          )

          if existing_prediction
            prediction_data = existing_prediction[:data]
            @logger.info "♻️ [Adjust] Using existing prediction data (target_end_date: #{effective_planning_end})"
          else
            @logger.info "🔮 [Adjust] Generating new prediction data (target_end_date: #{effective_planning_end})"
            weather_info = weather_prediction_service.predict_for_cultivation_plan(
              plan_weather: plan_weather_dto,
              target_end_date: effective_planning_end
            )
            prediction_data = weather_info[:data]
          end

          historical_data_start = effective_planning_start
          historical_data_end = @clock.today - 1
          historical_rows = @plan_gateway.historical_weather_rows(
            historical_start: historical_data_start,
            historical_end: historical_data_end
          )

          weather_data =
            if historical_rows.empty?
              @logger.warn "⚠️ [Adjust] No historical weather data found. Proceeding with prediction data only."
              prediction_data
            else
              @logger.info "✅ [Adjust] Historical weather data loaded: #{historical_rows.count} records (#{historical_data_start} to #{historical_data_end})"

              facts = @plan_gateway.weather_location_facts
              current_year_formatted = Domain::WeatherData::Mappers::AdjustHistoricalPredictionMapper.build_historical_agrr_series(
                latitude: facts[:latitude],
                longitude: facts[:longitude],
                elevation: facts[:elevation],
                timezone: facts[:timezone],
                rows: historical_rows
              )

              merged = Domain::WeatherData::Mappers::AdjustHistoricalPredictionMapper.merge_historical_series_with_prediction(
                current_year_formatted,
                prediction_data
              )
              @logger.info "✅ [Adjust] Merged weather data: historical=#{historical_rows.count} records, prediction=#{prediction_data['data'].count} records"
              merged
            end

          weather_data = extend_prediction_if_needed!(
            weather_prediction_service,
            weather_data,
            effective_planning_end,
            historical_rows
          )

          [ weather_data, nil ]
        rescue *WEATHER_PHASE_EXCEPTIONS => e
          @logger.error "❌ [Adjust] Failed to get weather data: #{e.message}"
          [
            nil,
            {
              success: false,
              message: @translator.translate("api.errors.common.weather_fetch_failed", message: e.message),
              status: :internal_server_error
            }
          ]
        end

        def extend_prediction_if_needed!(weather_prediction_service, weather_data, effective_planning_end, historical_rows)
          merged_dates = Array(weather_data["data"]).map { |d| Date.parse(d["time"]) rescue nil }.compact
          merged_end_date = merged_dates.max

          return weather_data unless merged_end_date.nil? || merged_end_date < effective_planning_end

          @logger.warn "⚠️ [Adjust] Merged weather data ends at #{merged_end_date}, but effective_planning_end is #{effective_planning_end}. Extending prediction..."

          @plan_gateway.reload_plan_record!
          plan_weather_dto = @plan_gateway.cultivation_plan_weather_dto

          extended_weather_info = weather_prediction_service.predict_for_cultivation_plan(
            plan_weather: plan_weather_dto,
            target_end_date: effective_planning_end
          )
          extended_prediction_data = extended_weather_info[:data]

          new_weather =
            if historical_rows.empty?
              extended_prediction_data
            else
              facts = @plan_gateway.weather_location_facts
              current_year_formatted = Domain::WeatherData::Mappers::AdjustHistoricalPredictionMapper.build_historical_agrr_series(
                latitude: facts[:latitude],
                longitude: facts[:longitude],
                elevation: facts[:elevation],
                timezone: facts[:timezone],
                rows: historical_rows
              )
              Domain::WeatherData::Mappers::AdjustHistoricalPredictionMapper.merge_historical_series_with_prediction(
                current_year_formatted,
                extended_prediction_data
              )
            end

          @logger.info "✅ [Adjust] Extended prediction data to cover until #{effective_planning_end}"
          new_weather
        end

        def normalize_nested_weather_data(weather_data)
          if weather_data["data"].is_a?(Hash) && weather_data["data"]["data"].is_a?(Array)
            weather_data["data"]
          else
            weather_data
          end
        end

        def clamp_planning_start_to_weather!(weather_data, effective_planning_start)
          weather_dates = weather_data["data"]
          return effective_planning_start unless weather_dates.is_a?(Array) && weather_dates.any?

          weather_start_date = Date.parse(weather_dates.first["time"].to_s) rescue nil
          if weather_start_date && effective_planning_start < weather_start_date
            @logger.info "📅 [Adjust] Clamping planning_start from #{effective_planning_start} to #{weather_start_date} (weather data boundary)"
            weather_start_date
          else
            effective_planning_start
          end
        end

        def run_adjust_and_persist(plan_id:, moves:, fields:, crops:, weather_data:, interaction_rules:,
                                   effective_planning_start:, effective_planning_end:, current_allocation:,
                                   perf_start:, perf_db_load:)
          perf_before_adjust = @clock.now
          @logger.info "⏱️ [PERF] AdjustGateway.adjust() 呼び出し開始"
          @logger.info "📅 [Adjust] 計画期間: #{effective_planning_start} 〜 #{effective_planning_end} (制約として使用しない)"

          interactor = AgrrAdjustInteractor.new(
            gateway: @agrr_adjust_gateway,
            logger: @logger
          )
          result = interactor.call(
            current_allocation: current_allocation,
            moves: moves,
            fields: fields,
            crops: crops,
            weather_data: weather_data,
            planning_start: effective_planning_start,
            planning_end: effective_planning_end,
            interaction_rules: interaction_rules.empty? ? nil : { "rules" => interaction_rules },
            objective: "maximize_profit",
            enable_parallel: true
          )

          perf_after_adjust = @clock.now
          @logger.info "⏱️ [PERF] AdjustGateway.adjust() 完了: #{((perf_after_adjust - perf_before_adjust) * 1000).round(2)}ms"

          if result && result[:field_schedules].present?
            perf_before_save = @clock.now
            @save_adjusted_gateway.save_adjust_result!(plan_id: plan_id, result: result)
            perf_after_save = @clock.now
            @logger.info "⏱️ [PERF] DB保存完了: #{((perf_after_save - perf_before_save) * 1000).round(2)}ms"

            perf_end = @clock.now
            log_perf_summary(
              perf_start: perf_start,
              perf_db_load: perf_db_load,
              perf_before_adjust: perf_before_adjust,
              perf_after_adjust: perf_after_adjust,
              perf_before_save: perf_before_save,
              perf_after_save: perf_after_save,
              perf_end: perf_end
            )

            @plan_gateway.broadcast_optimization_complete(
              plan_id: plan_id,
              events_gateway: @optimization_events_gateway,
              status: "adjusted"
            )

            summary = @plan_gateway.plan_summary_for_adjust_response(plan_id: plan_id)
            {
              success: true,
              message: @translator.translate("optimization.messages.adjust_completed"),
              cultivation_plan: summary.merge(total_profit: result[:total_profit])
            }
          else
            @logger.error "❌ [Adjust] Result has no field_schedules"
            {
              success: false,
              message: @translator.translate("api.errors.optimization.result_empty"),
              status: :internal_server_error
            }
          end
        rescue ArgumentError => e
          @logger.error "❌ [Adjust] Invalid date format: #{e.message}"
          {
            success: false,
            message: @translator.translate("api.errors.common.invalid_date_format", message: e.message),
            status: :bad_request
          }
        rescue Adapters::Agrr::Gateways::BaseGateway::ExecutionError => e
          @logger.error "❌ [Adjust] Failed to adjust: #{e.message}"
          {
            success: false,
            message: @translator.translate("api.errors.optimization.adjust_failed", message: e.message),
            status: :internal_server_error
          }
        end

        def log_perf_summary(perf_start:, perf_db_load:, perf_before_adjust:, perf_after_adjust:, perf_before_save:, perf_after_save:, perf_end:)
          @logger.info "⏱️ [PERF] === 合計処理時間 ==="
          @logger.info "⏱️ [PERF] 全体: #{((perf_end - perf_start) * 1000).round(2)}ms"
          @logger.info "⏱️ [PERF] - DB読み込み: #{((perf_db_load - perf_start) * 1000).round(2)}ms"
          @logger.info "⏱️ [PERF] - データ構築: #{((perf_before_adjust - perf_db_load) * 1000).round(2)}ms"
          @logger.info "⏱️ [PERF] - agrr adjust実行: #{((perf_after_adjust - perf_before_adjust) * 1000).round(2)}ms"
          @logger.info "⏱️ [PERF] - DB保存: #{((perf_after_save - perf_before_save) * 1000).round(2)}ms"
        end
      end
    end
  end
end
