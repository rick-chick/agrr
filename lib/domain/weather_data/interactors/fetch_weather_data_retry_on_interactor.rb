# frozen_string_literal: true

module Domain
  module WeatherData
    module Interactors
      class FetchWeatherDataRetryOnInteractor
        include InputPorts::FetchWeatherDataRetryOnInputPort

        def initialize(farm_gateway:, presenter:, advance_phase_interactor:, mark_farm_weather_data_failed_interactor:, logger:, translator:)
          @farm_gateway = farm_gateway
          @presenter = presenter
          @advance_phase_interactor = advance_phase_interactor
          @mark_farm_weather_data_failed_interactor = mark_farm_weather_data_failed_interactor
          @logger = logger
          @translator = translator
        end

        def call(input_dto:)
          farm_id = input_dto[:farm_id]
          start_date = input_dto[:start_date]
          end_date = input_dto[:end_date]
          executions = input_dto[:executions]
          error_message = input_dto[:error_message]
          period_str = start_date.year == end_date.year ? "#{start_date.year}" : "#{start_date.year}-#{end_date.year}"

          @presenter.error "❌ [Farm##{farm_id}] Failed to fetch weather data for #{period_str} after #{executions} attempts"
          @presenter.error "   Final error: #{error_message}"

          error_msg = @translator.t("jobs.fetch_weather_data.retry_limit_exceeded", error: error_message)
          if farm_id
            @mark_farm_weather_data_failed_interactor.call(
              Domain::Farm::Dtos::MarkFarmWeatherDataFailedInput.new(
                farm_id: farm_id,
                error_message: error_msg
              )
            )
          end

          if input_dto[:cultivation_plan_id] && input_dto[:channel_class]
            @advance_phase_interactor.call(
              Domain::CultivationPlan::Dtos::AdvanceCultivationPlanPhaseInput.new(
                plan_id: input_dto[:cultivation_plan_id],
                phase_name: :phase_failed,
                channel_class: input_dto[:channel_class],
                failure_subphase: "fetching_weather"
              )
            )
          end
        end
      end
    end
  end
end
