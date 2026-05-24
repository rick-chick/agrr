# frozen_string_literal: true

module Domain
  module WeatherData
    module Interactors
      class InternalWeatherFetchStartInteractor
        def initialize(output_port:, gateway:, translator:, start_farm_weather_data_fetch_interactor:, calendar_today:)
          @output_port = output_port
          @gateway = gateway
          @translator = translator
          @start_farm_weather_data_fetch_interactor = start_farm_weather_data_fetch_interactor
          @calendar_today = calendar_today
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
          when :started, :needs_fetch
            snap = r.snapshot
            if r.kind == :needs_fetch
              started_farm = @start_farm_weather_data_fetch_interactor.call(
                Domain::Farm::Dtos::StartFarmWeatherDataFetchInput.new(
                  farm_id: snap.farm_id,
                  as_of: @calendar_today
                )
              )
              snap = snap.dup if snap.frozen?
              snap = InternalWeatherFetchStartGateway::WeatherFetchFarmSnapshot.new(
                farm_id: snap.farm_id,
                weather_data_status: started_farm&.weather_data_status || "fetching",
                weather_data_count: snap.weather_data_count,
                total_blocks: started_farm&.weather_data_total_years || snap.total_blocks
              )
            end
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
