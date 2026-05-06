# frozen_string_literal: true

module Presenters
  module Api
    module Weather
      class ApiWeatherHistoricalPresenter < Domain::ApiWeather::Ports::ApiWeatherHistoricalOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(weather_json)
          @view.render_response(json: weather_json, status: :ok)
        end

        def on_failure(dto)
          case dto.kind
          when Domain::ApiWeather::Dtos::ApiWeatherFailureDto::KIND_LOCATION_REQUIRED
            @view.render_response(
              json: { error: I18n.t("api.errors.common.location_required") },
              status: :bad_request
            )
          when Domain::ApiWeather::Dtos::ApiWeatherFailureDto::KIND_DAEMON_UNAVAILABLE
            @view.render_response(
              json: { error: I18n.t("api.errors.common.weather_service_unavailable") },
              status: :service_unavailable
            )
          when Domain::ApiWeather::Dtos::ApiWeatherFailureDto::KIND_COMMAND_FAILED
            @view.render_response(
              json: { error: I18n.t("api.errors.common.weather_fetch_failed", message: dto.message) },
              status: :internal_server_error
            )
          when Domain::ApiWeather::Dtos::ApiWeatherFailureDto::KIND_INVALID_JSON
            @view.render_response(
              json: { error: I18n.t("api.errors.common.weather_invalid_response") },
              status: :internal_server_error
            )
          end
        end
      end

      class ApiWeatherForecastPresenter < Domain::ApiWeather::Ports::ApiWeatherForecastOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(forecast_json)
          @view.render_response(json: forecast_json, status: :ok)
        end

        def on_failure(dto)
          case dto.kind
          when Domain::ApiWeather::Dtos::ApiWeatherFailureDto::KIND_LOCATION_REQUIRED
            @view.render_response(
              json: { error: I18n.t("api.errors.common.location_required") },
              status: :bad_request
            )
          when Domain::ApiWeather::Dtos::ApiWeatherFailureDto::KIND_DAEMON_UNAVAILABLE
            @view.render_response(
              json: { error: I18n.t("api.errors.common.weather_service_unavailable") },
              status: :service_unavailable
            )
          when Domain::ApiWeather::Dtos::ApiWeatherFailureDto::KIND_COMMAND_FAILED
            @view.render_response(
              json: { error: I18n.t("api.errors.common.forecast_fetch_failed", message: dto.message) },
              status: :internal_server_error
            )
          when Domain::ApiWeather::Dtos::ApiWeatherFailureDto::KIND_INVALID_JSON
            @view.render_response(
              json: { error: I18n.t("api.errors.common.weather_invalid_response") },
              status: :internal_server_error
            )
          end
        end
      end
    end
  end
end
