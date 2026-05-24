# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Interactors
      class FieldCultivationClimateDataInteractor < Domain::FieldCultivation::Ports::FieldCultivationClimateDataInputPort
        include Concerns::PlanFieldCultivationAuthorization

        def initialize(output_port:, logger:, user_id:, user_lookup:, climate_gateways_for_user:)
          @output_port = output_port
          @logger = logger
          @user_id = user_id
          @user_lookup = user_lookup
          @climate_gateways_for_user = climate_gateways_for_user
        end

        def call(input_dto)
          user_dto = @user_id.present? ? @user_lookup.find(@user_id) : nil
          bundle = @climate_gateways_for_user.call(user_dto)
          context_gateway = bundle.fetch(:context_gateway)
          weather_gateway = bundle.fetch(:weather_gateway)
          progress_gateway = bundle.fetch(:progress_gateway)
          use_mock_progress = bundle.fetch(:use_mock_progress)

          if user_dto
            assert_field_cultivation_plan_access!(user_dto, context_gateway, input_dto.field_cultivation_id)
          else
            assert_public_field_cultivation_plan_access!(context_gateway, input_dto.field_cultivation_id)
          end

          field_cultivation_id = input_dto.field_cultivation_id
          display_start_date = input_dto.display_start_date
          display_end_date = input_dto.display_end_date

          climate_data = assemble_climate_data(
            context_gateway: context_gateway,
            weather_gateway: weather_gateway,
            progress_gateway: progress_gateway,
            use_mock_progress: use_mock_progress,
            field_cultivation_id: field_cultivation_id,
            display_start_date: display_start_date,
            display_end_date: display_end_date
          )

          if climate_data.nil?
            @logger.warn("[FieldCultivationClimateDataInteractor] Missing climate data for field_cultivation_id=#{field_cultivation_id}")
            @output_port.on_error(
              Domain::Shared::Dtos::Error.new("Field cultivation climate data not found")
            )
            return
          end

          filtered_data = apply_display_range(climate_data, display_start_date, display_end_date)
          @output_port.present(filtered_data)
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          @output_port.on_error(Domain::Shared::Dtos::Error.new("Forbidden"))
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @logger.warn("[FieldCultivationClimateDataInteractor] Field cultivation not found: #{e.message}")
          @output_port.on_error(Domain::Shared::Dtos::Error.new(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @logger.warn("[FieldCultivationClimateDataInteractor] Record invalid: #{e.message}")
          @output_port.on_error(Domain::Shared::Dtos::Error.new(e.message))
        rescue Domain::FieldCultivation::Errors::NoWeatherLocationError,
               Domain::FieldCultivation::Errors::NoCultivationPeriodError,
               Domain::FieldCultivation::Errors::WeatherPayloadInvalidError => e
          @logger.warn("[FieldCultivationClimateDataInteractor] Climate precondition: #{e.class}: #{e.message}")
          @output_port.on_error(Domain::Shared::Dtos::Error.new(e.message))
        end

        private

        def assemble_climate_data(context_gateway:, weather_gateway:, progress_gateway:, use_mock_progress:,
                                  field_cultivation_id:, display_start_date:, display_end_date:)
          context = context_gateway.load_context(field_cultivation_id: field_cultivation_id)
          weather_payload = fetch_weather_payload(
            context: context,
            weather_gateway: weather_gateway,
            display_start_date: display_start_date,
            display_end_date: display_end_date
          )
          return nil if weather_payload.nil?

          weather_records = Mappers::FieldCultivationClimateDataMapper.extract_weather_records(
            weather_payload,
            context.start_date,
            context.completion_date
          )
          progress_result = progress_gateway.calculate_progress(
            context: context,
            weather_payload: weather_payload,
            use_mock: use_mock_progress
          )

          Mappers::FieldCultivationClimateDataMapper.build_output(
            context: context,
            weather_records: weather_records,
            progress_result: progress_result
          )
        rescue Domain::FieldCultivation::Errors::NoWeatherLocationError,
               Domain::FieldCultivation::Errors::NoCultivationPeriodError => e
          @logger.info "Fallback to on-the-fly prediction for field_cultivation_id=#{field_cultivation_id} (#{e.class})"
          assemble_climate_data_from_fallback(
            context_gateway: context_gateway,
            weather_gateway: weather_gateway,
            progress_gateway: progress_gateway,
            use_mock_progress: use_mock_progress,
            field_cultivation_id: field_cultivation_id,
            display_start_date: display_start_date,
            display_end_date: display_end_date
          )
        end

        def assemble_climate_data_from_fallback(context_gateway:, weather_gateway:, progress_gateway:, use_mock_progress:,
                                                field_cultivation_id:, display_start_date:, display_end_date:)
          context = context_gateway.load_context(field_cultivation_id: field_cultivation_id)
          weather_payload = weather_gateway.fetch_fallback_weather_payload(
            context: context,
            display_start_date: display_start_date,
            display_end_date: display_end_date
          )
          weather_gateway.persist_predicted_weather_if_absent(
            plan_id: context.plan_id,
            weather_payload: weather_payload
          )

          weather_records = Mappers::FieldCultivationClimateDataMapper.extract_weather_records(
            weather_payload,
            context.start_date,
            context.completion_date
          )
          progress_result = progress_gateway.calculate_progress(
            context: context,
            weather_payload: weather_payload,
            use_mock: use_mock_progress
          )

          Mappers::FieldCultivationClimateDataMapper.build_output(
            context: context,
            weather_records: weather_records,
            progress_result: progress_result
          )
        end

        def fetch_weather_payload(context:, weather_gateway:, display_start_date:, display_end_date:)
          weather_gateway.fetch_primary_weather_payload(
            context: context,
            display_start_date: display_start_date,
            display_end_date: display_end_date
          )
        end

        def apply_display_range(climate_data, display_start_date, display_end_date)
          return climate_data unless display_start_date || display_end_date

          gantt_start = parse_date(display_start_date)
          gantt_end = parse_date(display_end_date)
          return climate_data unless gantt_start && gantt_end

          cultivation_start = parse_date(climate_data.field_cultivation[:start_date] || climate_data.field_cultivation["start_date"])
          cultivation_end = parse_date(climate_data.field_cultivation[:completion_date] || climate_data.field_cultivation["completion_date"])

          effective_start = [
            cultivation_start,
            gantt_start
          ].compact.max

          effective_end = [
            cultivation_end,
            gantt_end
          ].compact.min

          if effective_start > effective_end
            effective_start = gantt_start
            effective_end = gantt_end
          end

          filtered_weather = filter_weather_data(climate_data.weather_data, effective_start, effective_end)
          filtered_gdd = filter_gdd_data(climate_data.gdd_data, effective_start, effective_end)

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

          Domain::FieldCultivation::Dtos::FieldCultivationClimateDataOutput.new(
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
          Domain::Shared.to_array(weather_data).select do |datum|
            date_value = parse_date(datum["date"] || datum[:date])
            next false unless date_value

            date_value >= range_start && date_value <= range_end
          end
        end

        def filter_gdd_data(gdd_data, range_start, range_end)
          Domain::Shared.to_array(gdd_data).select do |datum|
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
