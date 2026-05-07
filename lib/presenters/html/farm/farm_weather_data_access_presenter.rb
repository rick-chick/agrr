# frozen_string_literal: true

module Presenters
  module Html
    module Farm
      class FarmWeatherDataAccessPresenter < Domain::WeatherData::Ports::FarmWeatherDataAccessOutputPort
        def initialize(view:, translator:)
          @view = view
          @translator = translator
        end

        def on_index_success(farm:, period:, data:)
          @view.render_response(
            json: {
              success: true,
              farm: farm,
              period: {
                start_date: period[:start_date],
                end_date: period[:end_date]
              },
              data: data
            },
            status: :ok
          )
        end

        def on_prediction_cached_success(farm:, period:, is_prediction:, predicted_at:, model:, data:)
          @view.render_response(
            json: {
              success: true,
              farm: farm,
              period: period,
              is_prediction: is_prediction,
              predicted_at: predicted_at,
              model: model,
              data: data
            },
            status: :ok
          )
        end

        def on_prediction_queued(farm_id:, farm_name:)
          @view.render_response(
            json: {
              success: true,
              message: @translator.t("farms.weather_section.prediction_job_started"),
              farm: {
                id: farm_id,
                name: farm_name
              },
              status: "processing"
            },
            status: :ok
          )
        end

        def on_farm_not_found
          @view.render_response(
            json: {
              success: false,
              message: @translator.t("farms.weather_data.farm_not_found")
            },
            status: :not_found
          )
        end

        def on_no_weather_location
          @view.render_response(
            json: {
              success: false,
              message: @translator.t("farms.weather_data.no_weather_data")
            },
            status: :not_found
          )
        end

        def on_insufficient_historical_data
          @view.render_response(
            json: {
              success: false,
              message: @translator.t("farms.weather_data.insufficient_historical_data")
            },
            status: :unprocessable_entity
          )
        end

        def on_enqueue_failed(error_message:)
          @view.render_response(
            json: {
              success: false,
              message: @translator.t("farms.weather_data.job_queue_failed", error: error_message)
            },
            status: :internal_server_error
          )
        end
      end
    end
  end
end
