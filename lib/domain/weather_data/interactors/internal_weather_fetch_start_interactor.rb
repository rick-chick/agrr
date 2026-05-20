# frozen_string_literal: true

module Domain
  module WeatherData
    module Interactors
      class InternalWeatherFetchStartInteractor
        def initialize(output_port:, gateway:, translator:)
          @output_port = output_port
          @gateway = gateway
          @translator = translator
        end

        def call(input_dto)
          r = @gateway.start_internal_weather_data_fetch(farm_id: input_dto.farm_id)
          case r.kind
          when :farm_not_found
            @output_port.on_failure(
              Dtos::InternalWeatherFetchFailure.new(
                message: @translator.t("api.errors.common.farm_not_found"),
                http_status: :not_found
              )
            )
          when :completed
            snap = r.snapshot
            @output_port.on_success(
              Dtos::InternalWeatherFetchStartOutput.new(
                variant: Dtos::InternalWeatherFetchStartOutput::VARIANT_ALREADY_COMPLETED,
                farm_id: snap.farm_id,
                weather_data_status: snap.weather_data_status,
                weather_data_count: snap.weather_data_count,
                total_blocks: snap.total_blocks
              )
            )
          when :started
            snap = r.snapshot
            @output_port.on_success(
              Dtos::InternalWeatherFetchStartOutput.new(
                variant: Dtos::InternalWeatherFetchStartOutput::VARIANT_FETCH_STARTED,
                farm_id: snap.farm_id,
                weather_data_status: snap.weather_data_status,
                weather_data_count: snap.weather_data_count,
                total_blocks: snap.total_blocks
              )
            )
          when :failed
            @output_port.on_failure(
              Dtos::InternalWeatherFetchFailure.new(
                message: r.error_message.to_s,
                http_status: :internal_server_error
              )
            )
          else
            raise ArgumentError, "unexpected gateway result kind: #{r.kind.inspect}"
          end
        end
      end
    end
  end
end
