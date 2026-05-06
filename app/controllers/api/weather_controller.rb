# frozen_string_literal: true

class Api::WeatherController < ApplicationController
  before_action :authenticate_user!

  # GET /api/weather/historical
  def historical
    CompositionRoot.api_weather_historical_interactor(
      output_port: Presenters::Api::Weather::ApiWeatherHistoricalPresenter.new(view: self)
    ).call(
      location: params[:location],
      start_date: params[:start_date],
      end_date: params[:end_date],
      days: params[:days],
      data_source: params[:data_source] || "noaa"
    )
  end

  # GET /api/weather/forecast
  def forecast
    CompositionRoot.api_weather_forecast_interactor(
      output_port: Presenters::Api::Weather::ApiWeatherForecastPresenter.new(view: self)
    ).call(location: params[:location])
  end

  # GET /api/weather/status
  def status
    gateway = CompositionRoot.agrr_service_weather_query_gateway
    if gateway.daemon_running?
      render json: { status: "running", message: I18n.t("api.messages.common.weather_service_available") }
    else
      render json: { status: "stopped", message: I18n.t("api.messages.common.weather_service_not_available") }, status: :service_unavailable
    end
  end

  def render_response(json:, status:)
    render json: json, status: status
  end

  private
end
