# frozen_string_literal: true

class Api::WeatherController < ApplicationController
  before_action :authenticate_user!
  before_action :set_agrr_service

  # GET /api/weather/historical
  def historical
    location = params[:location]
    start_date = params[:start_date]
    end_date = params[:end_date]
    days = params[:days]
    data_source = params[:data_source] || 'openmeteo'

    if location.blank?
      render json: { error: I18n.t('api.errors.common.location_required') }, status: :bad_request
      return
    end

    begin
      weather_data = @agrr_service.weather(
        location: location,
        start_date: start_date,
        end_date: end_date,
        days: days&.to_i,
        data_source: data_source,
        json: true
      )

      render json: JSON.parse(weather_data)
    rescue AgrrService::DaemonNotRunningError
      render json: { error: I18n.t('api.errors.common.weather_service_unavailable') }, status: :service_unavailable
    rescue AgrrService::CommandExecutionError => e
      render json: { error: I18n.t('api.errors.common.weather_fetch_failed', message: e.message) }, status: :internal_server_error
    rescue JSON::ParserError
      render json: { error: I18n.t('api.errors.common.weather_invalid_response') }, status: :internal_server_error
    end
  end

  # GET /api/weather/forecast
  def forecast
    location = params[:location]

    if location.blank?
      render json: { error: I18n.t('api.errors.common.location_required') }, status: :bad_request
      return
    end

    begin
      forecast_data = @agrr_service.forecast(
        location: location,
        json: true
      )

      render json: JSON.parse(forecast_data)
    rescue AgrrService::DaemonNotRunningError
      render json: { error: I18n.t('api.errors.common.weather_service_unavailable') }, status: :service_unavailable
    rescue AgrrService::CommandExecutionError => e
      render json: { error: I18n.t('api.errors.common.forecast_fetch_failed', message: e.message) }, status: :internal_server_error
    rescue JSON::ParserError
      render json: { error: I18n.t('api.errors.common.weather_invalid_response') }, status: :internal_server_error
    end
  end

  # GET /api/weather/status
  def status
    if @agrr_service.daemon_running?
      render json: { status: 'running', message: I18n.t('api.messages.common.weather_service_available') }
    else
      render json: { status: 'stopped', message: I18n.t('api.messages.common.weather_service_not_available') }, status: :service_unavailable
    end
  end

  private

  def set_agrr_service
    @agrr_service = AgrrService.new
  end
end
