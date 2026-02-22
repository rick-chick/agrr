# frozen_string_literal: true

module Domain
  module WeatherData
    module Interactors
      class FetchWeatherDataDiscardOnInteractor
        include InputPorts::FetchWeatherDataDiscardOnInputPort

        def initialize(farm_gateway:, presenter:, translator:)
          @farm_gateway = farm_gateway
          @presenter = presenter
          @translator = translator
        end

        def execute(input_dto:)
          farm_id = input_dto[:farm_id]
          start_date = input_dto[:start_date]
          end_date = input_dto[:end_date]
          error_message = input_dto[:error_message]
          period_str = start_date.year == end_date.year ? "#{start_date.year}" : "#{start_date.year}-#{end_date.year}"

          @presenter.error "❌ [Farm##{farm_id}] Invalid data for #{period_str}: #{error_message}"

          error_msg = @translator.t('jobs.fetch_weather_data.validation_error', error: error_message)
          @farm_gateway.mark_weather_data_failed(farm_id, error_msg) if farm_id
        end
      end
    end
  end
end
