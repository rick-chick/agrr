# frozen_string_literal: true

module Domain
  module WeatherData
    module Interactors
      class FetchWeatherDataRetryOnInteractor
        include InputPorts::FetchWeatherDataRetryOnInputPort

        def initialize(farm_gateway:, presenter:, cultivation_plan_gateway:, logger:, translator:)
          @farm_gateway = farm_gateway
          @presenter = presenter
          @cultivation_plan_gateway = cultivation_plan_gateway
          @logger = logger
          @translator = translator
        end

        def execute(input_dto:)
          farm_id = input_dto[:farm_id]
          start_date = input_dto[:start_date]
          end_date = input_dto[:end_date]
          executions = input_dto[:executions]
          error_message = input_dto[:error_message]
          period_str = start_date.year == end_date.year ? "#{start_date.year}" : "#{start_date.year}-#{end_date.year}"

          @presenter.error "❌ [Farm##{farm_id}] Failed to fetch weather data for #{period_str} after #{executions} attempts"
          @presenter.error "   Final error: #{error_message}"

          error_msg = @translator.t('jobs.fetch_weather_data.retry_limit_exceeded', error: error_message)
          @farm_gateway.mark_weather_data_failed(farm_id, error_msg) if farm_id

          if input_dto[:cultivation_plan_id] && input_dto[:channel_class]
            @cultivation_plan_gateway.update_phase(
              input_dto[:cultivation_plan_id],
              :phase_failed,
              'fetching_weather',
              input_dto[:channel_class]
            )
          end
        end
      end
    end
  end
end
