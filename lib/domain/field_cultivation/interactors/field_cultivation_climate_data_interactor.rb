# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Interactors
      class FieldCultivationClimateDataInteractor < Domain::FieldCultivation::Ports::FieldCultivationClimateDataInputPort
        def initialize(output_port:, gateway:, weather_data_gateway:, prediction_factory:, progress_factory:, translator: nil, logger: Rails.logger)
          @output_port = output_port
          @gateway = gateway
          @weather_data_gateway = weather_data_gateway
          @prediction_factory = prediction_factory
          @progress_factory = progress_factory
          @translator = translator || Adapters::Translators::RailsTranslator.new
          @logger = logger
        end

        def call(input_dto)
          field_cultivation_id = input_dto.field_cultivation_id
          display_start_date = input_dto.display_start_date
          display_end_date = input_dto.display_end_date

          climate_data = safe_fetch_climate_data(field_cultivation_id, display_start_date, display_end_date)

          if climate_data.nil?
            @logger.warn("[FieldCultivationClimateDataInteractor] Missing climate data for field_cultivation_id=#{field_cultivation_id}")
            @output_port.on_error(
              Domain::Shared::Dtos::ErrorDto.new('Field cultivation climate data not found')
            )
            return
          end

          filtered_data = apply_display_range(climate_data, display_start_date, display_end_date)
          @output_port.present(filtered_data)
        rescue ActiveRecord::RecordNotFound => e
          @logger.warn("[FieldCultivationClimateDataInteractor] Field cultivation not found: #{e.message}")
          @output_port.on_error(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue StandardError => e
          @logger.error("[FieldCultivationClimateDataInteractor] Unexpected error: #{e.class}: #{e.message}")
          @logger.error(e.backtrace.join("\n")) if e.backtrace
          @output_port.on_error(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end

        private

        def safe_fetch_climate_data(field_cultivation_id, display_start_date, display_end_date)
          begin
            @gateway.fetch_field_cultivation_climate_data(field_cultivation_id: field_cultivation_id)
          rescue StandardError => e
            if fallback_trigger?(e)
              @logger.info "Fallback to on-the-fly prediction for field_cultivation_id=#{field_cultivation_id}"
              fallback_fetch(field_cultivation_id, display_start_date, display_end_date)
            else
              raise
            end
          end
        end

        def fallback_trigger?(error)
          error.message.include?('weather_format_invalid') || error.message.include?('no_weather_data') || error.message.include?('no_cultivation_period')
        end

        def fallback_fetch(field_cultivation_id, display_start_date, display_end_date)
          field_cultivation = @gateway.find_authorized_field_cultivation(field_cultivation_id)
          plan = field_cultivation.cultivation_plan
          farm = plan.farm
          weather_location = farm.weather_location

          @gateway.ensure_weather_location!(farm)
          @gateway.ensure_cultivation_period!(field_cultivation)

          crop = @gateway.fetch_crop(field_cultivation, plan_type_public: plan.plan_type_public?)
          raise ActiveRecord::RecordNotFound, @translator.t('api.errors.crop_not_found') unless crop

          weather_payload = fallback_get_weather_data_for_period(weather_location, field_cultivation.start_date, field_cultivation.completion_date, farm.latitude, farm.longitude, display_start_date, display_end_date)

          # 予測データをCultivationPlanに保存（次回以降のキャッシュとして使用）
          unless plan.predicted_weather_data.present?
            plan.update!(predicted_weather_data: weather_payload)
            @logger.info "💾 [FieldCultivationClimateDataInteractor] Saved prediction data to CultivationPlan##{plan.id}"
          end

          weather_data_records = @gateway.extract_actual_weather_data(weather_payload, field_cultivation.start_date, field_cultivation.completion_date)

          temp_req = crop.crop_stages.order(:order).first&.temperature_requirement

          progress_result = @progress_factory.call.calculate_progress(
            crop: crop,
            start_date: field_cultivation.start_date,
            weather_data: weather_payload
          )

          daily_gdd, baseline_gdd, filtered_records, progress_records = @gateway.build_daily_gdd(
            progress_result,
            weather_data_records,
            field_cultivation,
            temp_req&.base_temperature || 10.0
          )

          @gateway.build_success_dto(
            field_cultivation: field_cultivation,
            farm: farm,
            weather_data_records: weather_data_records,
            temp_req: temp_req,
            optimal_temperature_range: @gateway.build_optimal_temperature_range(temp_req),
            daily_gdd: daily_gdd,
            progress_result: progress_result,
            stages: @gateway.build_stage_requirements(crop),
            baseline_gdd: baseline_gdd,
            filtered_records: filtered_records,
            progress_records: progress_records
          )
        end

        # 過去Controller get_weather_data_for_period完全移植
        def fallback_get_weather_data_for_period(weather_location, start_date, end_date, latitude, longitude, display_start_date, display_end_date)
          training_start_date = Date.current - 20.years
          training_end_date = Date.current - 2.days
          training_data = @weather_data_gateway.weather_data_for_period(
            weather_location_id: weather_location.id,
            start_date: training_start_date,
            end_date: training_end_date
          )

          training_formatted = {
            'latitude' => latitude,
            'longitude' => longitude,
            'timezone' => weather_location.timezone || 'Asia/Tokyo',
            'data' => training_data.filter_map do |datum|
              next if datum.temperature_max.nil? || datum.temperature_min.nil?
              temp_mean = datum.temperature_mean || (datum.temperature_max + datum.temperature_min) / 2.0
              {
                'time' => datum.date.to_s,
                'temperature_2m_max' => datum.temperature_max.to_f,
                'temperature_2m_min' => datum.temperature_min.to_f,
                'temperature_2m_mean' => temp_mean.to_f,
                'precipitation_sum' => (datum.precipitation || 0.0).to_f
              }
            end
          }

          prediction_days = (end_date - training_end_date).to_i

          if prediction_days > 0
            prediction_gateway = Agrr::PredictionGateway.new
            future = prediction_gateway.predict(
              historical_data: training_formatted,
              days: prediction_days,
              model: 'lightgbm'
            )

            # 表示期間に応じた実測データを取得
            observed_start = display_start_date || Date.new(Date.current.year, 1, 1)
            observed_end = display_end_date || training_end_date
            observed_end = [observed_end, Date.current - 1.day].min # 昨日まで

            current_year_data = @weather_data_gateway.weather_data_for_period(
              weather_location_id: weather_location.id,
              start_date: observed_start,
              end_date: observed_end
            )

            current_year_formatted = {
              'latitude' => latitude,
              'longitude' => longitude,
              'timezone' => weather_location.timezone || 'Asia/Tokyo',
              'data' => current_year_data.filter_map do |datum|
                next if datum.temperature_max.nil? || datum.temperature_min.nil?
                temp_mean = datum.temperature_mean || (datum.temperature_max + datum.temperature_min) / 2.0
                {
                  'time' => datum.date.to_s,
                  'temperature_2m_max' => datum.temperature_max,
                  'temperature_2m_min' => datum.temperature_min,
                  'temperature_2m_mean' => temp_mean,
                  'precipitation_sum' => datum.precipitation || 0.0
                }
              end
            }

            merged_data = current_year_formatted['data'] + Array(future['data'])

            {
              'latitude' => latitude,
              'longitude' => longitude,
              'timezone' => weather_location.timezone || 'Asia/Tokyo',
              'data' => merged_data
            }
          else
            @weather_data_gateway.format_for_agrr(
              weather_data_dtos: @weather_data_gateway.weather_data_for_period(weather_location_id: weather_location.id, start_date:, end_date:),
              weather_location: weather_location
            )
          end
        end

        def apply_display_range(climate_data, display_start_date, display_end_date)
          return climate_data unless display_start_date || display_end_date

          # ガントチャートの表示範囲（24ヶ月固定）
          gantt_start = parse_date(display_start_date)
          gantt_end = parse_date(display_end_date)
          return climate_data unless gantt_start && gantt_end

          # 作付期間
          cultivation_start = parse_date(climate_data.field_cultivation[:start_date] || climate_data.field_cultivation['start_date'])
          cultivation_end = parse_date(climate_data.field_cultivation[:completion_date] || climate_data.field_cultivation['completion_date'])

          # 全てのコンポーネントの幅: 作付期間 ∩ ガントチャート範囲
          # 気温データが存在しない場合でも作付期間全体を表示
          effective_start = [
            cultivation_start,
            gantt_start
          ].compact.max

          effective_end = [
            cultivation_end,
            gantt_end
          ].compact.min

          # 共通部分が存在しない場合はガントチャート範囲を使用
          if effective_start > effective_end
            effective_start = gantt_start
            effective_end = gantt_end
          end

          filtered_weather = filter_weather_data(climate_data.weather_data, effective_start, effective_end)
          filtered_gdd = filter_gdd_data(climate_data.gdd_data, effective_start, effective_end)

          # field_cultivationの期間も同じ範囲に調整
          adjusted_field_cultivation = climate_data.field_cultivation.merge(
            start_date: effective_start.to_s,
            completion_date: effective_end.to_s
          )

          debug_info = (climate_data.debug_info || {}).merge(
            display_range: {
              gantt_start: gantt_start.to_s,
              gantt_end: gantt_end.to_s,
              cultivation_start: cultivation_start&.to_s,
              cultivation_end: cultivation_end&.to_s,
              effective_start: effective_start.to_s,
              effective_end: effective_end.to_s,
              weather_records: filtered_weather.length,
              gdd_records: filtered_gdd.length,
              note: 'All components use intersection of cultivation period and gantt chart bounds'
            }
          )

          Domain::FieldCultivation::Dtos::FieldCultivationClimateDataSuccessDto.new(
            field_cultivation: adjusted_field_cultivation,
            farm: climate_data.farm,
            crop_requirements: climate_data.crop_requirements,
            weather_data: filtered_weather,
            gdd_data: filtered_gdd,
            stages: climate_data.stages,
            progress_result: climate_data.progress_result,
            debug_info: debug_info
          )
        end

        def filter_weather_data(weather_data, range_start, range_end)
          Array(weather_data).select do |datum|
            date_value = parse_date(datum['date'] || datum[:date])
            next false unless date_value
            date_value >= range_start && date_value <= range_end
          end
        end

        def filter_gdd_data(gdd_data, range_start, range_end)
          Array(gdd_data).select do |datum|
            date_value = parse_date(datum['date'] || datum[:date])
            next false unless date_value
            date_value >= range_start && date_value <= range_end
          end
        end

        def parse_date(value)
          return nil unless value

          Date.parse(value.to_s)
        rescue ArgumentError
          nil
        end
      end
    end
  end
end