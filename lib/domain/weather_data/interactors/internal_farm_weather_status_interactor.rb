# frozen_string_literal: true

module Domain
  module WeatherData
    module Interactors
      class InternalFarmWeatherStatusInteractor
        def initialize(output_port:, gateway:, translator:)
          @output_port = output_port
          @gateway = gateway
          @translator = translator
        end

        def call(input_dto)
          r = @gateway.weather_status_snapshot(farm_id: input_dto.farm_id)
          if r.farm_not_found?
            @output_port.on_failure(
              Dtos::InternalWeatherFetchFailure.new(
                message: @translator.t("api.errors.common.farm_not_found"),
                http_status: :not_found
              )
            )
          elsif r.ok?
            @output_port.on_success(r.success)
          else
            raise ArgumentError, "unexpected outcome: #{r.outcome.inspect}"
          end
        end
      end
    end
  end
end
