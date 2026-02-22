# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Interactors
      class FieldCultivationClimateDataInteractor < Domain::FieldCultivation::Ports::FieldCultivationClimateDataInputPort
        def initialize(output_port:, gateway:, weather_data_gateway:, prediction_factory:, progress_factory:, logger: Rails.logger)
          @output_port = output_port
          @gateway = gateway
          @weather_data_gateway = weather_data_gateway
          @prediction_factory = prediction_factory
          @progress_factory = progress_factory
          @logger = logger
        end

        def call(input_dto)
          field_cultivation_id = input_dto.field_cultivation_id

          climate_data = safe_fetch_climate_data(field_cultivation_id)

          if climate_data.nil?
            @logger.warn("[FieldCultivationClimateDataInteractor] Missing climate data for field_cultivation_id=#{field_cultivation_id}")
            @output_port.on_error(
              Domain::Shared::Dtos::ErrorDto.new('Field cultivation climate data not found')
            )
            return
          end

          @output_port.present(climate_data)
        rescue ActiveRecord::RecordNotFound => e
          @logger.warn("[FieldCultivationClimateDataInteractor] Field cultivation not found: #{e.message}")
          @output_port.on_error(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue StandardError => e
          @logger.error("[FieldCultivationClimateDataInteractor] Unexpected error: #{e.class}: #{e.message}")
          @logger.error(e.backtrace.join("\n")) if e.backtrace
          @output_port.on_error(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end

        private

        def safe_fetch_climate_data(field_cultivation_id)
          begin
            @gateway.fetch_field_cultivation_climate_data(field_cultivation_id: field_cultivation_id)
          rescue StandardError => e
            if fallback_trigger?(e)
              @logger.info "Fallback to on-the-fly prediction for field_cultivation_id=#{field_cultivation_id}"
              fallback_fetch(field_cultivation_id)
            else
              raise
            end
          end
        end

        def fallback_trigger?(error)
          error.message.include?('weather_format_invalid') || error.message.include?('no_weather_data') || error.message.include?('no_cultivation_period')
        end

        def fallback_fetch(field_cultivation_id)
          field_cultivation = @gateway.find_authorized_field_cultivation(field_cultivation_id)
          plan = field_cultivation.cultivation_plan
          farm = plan.farm

          @gateway.ensure_weather_location!(farm)
          @gateway.ensure_cultivation_period!(field_cultivation)

          crop = @gateway.fetch_crop(field_cultivation, plan_type_public: plan.plan_type_public?)
          raise ActiveRecord::RecordNotFound, I18n.t('api.errors.crop_not_found') unless crop

          service = @prediction_factory.call(farm.weather_location, farm)
          prediction_info = service.predict_for_cultivation_plan(plan)
          weather_payload = prediction_info[:data]

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
      end
    end
  end
end