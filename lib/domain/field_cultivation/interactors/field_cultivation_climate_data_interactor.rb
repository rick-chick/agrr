# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Interactors
      class FieldCultivationClimateDataInteractor < Domain::FieldCultivation::Ports::FieldCultivationClimateDataInputPort
        def initialize(output_port:, user_id: nil, gateway:, logger:, user_lookup:)
          @output_port = output_port
          @user_id = user_id
          @gateway = gateway
          @logger = logger
          @user_lookup = user_lookup
        end

        def call(input_dto)
          field_cultivation_id = input_dto.field_cultivation_id
          display_start_date = input_dto.display_start_date
          display_end_date = input_dto.display_end_date

          climate_data = safe_fetch_climate_data(field_cultivation_id, display_start_date, display_end_date)

          if climate_data.nil?
            @logger.warn("[FieldCultivationClimateDataInteractor] Missing climate data for field_cultivation_id=#{field_cultivation_id}")
            @output_port.on_error(
              Domain::Shared::Dtos::ErrorDto.new("Field cultivation climate data not found")
            )
            return
          end

          filtered_data = apply_display_range(climate_data, display_start_date, display_end_date)
          @output_port.present(filtered_data)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
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
            @gateway.fetch_field_cultivation_climate_data(
              field_cultivation_id: field_cultivation_id,
              display_start_date: display_start_date,
              display_end_date: display_end_date
            )
          rescue StandardError => e
            if fallback_trigger?(e)
              @logger.info "Fallback to on-the-fly prediction for field_cultivation_id=#{field_cultivation_id}"
              @gateway.climate_data_fallback_dto(
                field_cultivation_id: field_cultivation_id,
                display_start_date: display_start_date,
                display_end_date: display_end_date
              )
            else
              raise
            end
          end
        end

        def fallback_trigger?(error)
          error.message.include?("weather_format_invalid") || error.message.include?("no_weather_data") || error.message.include?("no_cultivation_period")
        end

        def apply_display_range(climate_data, display_start_date, display_end_date)
          return climate_data unless display_start_date || display_end_date

          # ガントチャートの表示範囲（24ヶ月固定）
          gantt_start = parse_date(display_start_date)
          gantt_end = parse_date(display_end_date)
          return climate_data unless gantt_start && gantt_end

          # 作付期間
          cultivation_start = parse_date(climate_data.field_cultivation[:start_date] || climate_data.field_cultivation["start_date"])
          cultivation_end = parse_date(climate_data.field_cultivation[:completion_date] || climate_data.field_cultivation["completion_date"])

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
              note: "All components use intersection of cultivation period and gantt chart bounds"
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
          Domain::Shared::ValidationHelpers.to_array(weather_data).select do |datum|
            date_value = parse_date(datum["date"] || datum[:date])
            next false unless date_value
            date_value >= range_start && date_value <= range_end
          end
        end

        def filter_gdd_data(gdd_data, range_start, range_end)
          Domain::Shared::ValidationHelpers.to_array(gdd_data).select do |datum|
            date_value = parse_date(datum["date"] || datum[:date])
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
