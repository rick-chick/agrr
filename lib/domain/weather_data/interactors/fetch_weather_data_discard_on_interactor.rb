# frozen_string_literal: true

module Domain
  module WeatherData
    module Interactors
      class FetchWeatherDataDiscardOnInteractor
        include InputPorts::FetchWeatherDataDiscardOnInputPort

        def initialize(farm_gateway:, presenter:, logger:, translator:, mark_farm_weather_data_failed_interactor:)
          @farm_gateway = farm_gateway
          @presenter = presenter
          @logger = logger
          @translator = translator
          @mark_farm_weather_data_failed_interactor = mark_farm_weather_data_failed_interactor
        end

        def call(input_dto:)
          farm_id = input_dto[:farm_id]
          start_date = input_dto[:start_date]
          end_date = input_dto[:end_date]
          error_message = input_dto[:error_message]
          period_str = start_date.year == end_date.year ? "#{start_date.year}" : "#{start_date.year}-#{end_date.year}"

          @presenter.error "❌ [Farm##{farm_id}] Invalid data for #{period_str}: #{error_message}"

          error_msg = @translator.t("jobs.fetch_weather_data.validation_error", error: error_message)
          if farm_id
            @mark_farm_weather_data_failed_interactor.call(
              Domain::Farm::Dtos::MarkFarmWeatherDataFailedInput.new(
                farm_id: farm_id,
                error_message: error_msg
              )
            )
          end
        end
      end
    end
  end
end
