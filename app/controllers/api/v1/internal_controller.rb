# frozen_string_literal: true

module Api
  module V1
    # 内部スクリプト専用のAPIコントローラー
    # セキュリティ: 開発環境とテスト環境のみ許可
    class InternalController < ApplicationController
      # CSRF保護をスキップ（内部API用）
      skip_before_action :verify_authenticity_token
      skip_before_action :authenticate_user!

      # 開発・テスト環境のみ許可
      before_action :check_environment

      # POST /api/v1/internal/farms/:farm_id/fetch_weather_data
      # 特定の農場の天気データを取得開始
      def fetch_weather_data
        input_dto = Domain::WeatherData::Dtos::InternalWeatherFetchStartInput.new(farm_id: params[:farm_id])
        presenter = Adapters::WeatherData::Presenters::InternalWeatherFetchStartApiPresenter.new(
          view: self,
          translator: CompositionRoot.translator
        )
        interactor = Domain::WeatherData::Interactors::InternalWeatherFetchStartInteractor.new(
          output_port: presenter,
          gateway: CompositionRoot.internal_weather_fetch_start_gateway,
          translator: CompositionRoot.translator,
          start_farm_weather_data_fetch_interactor: CompositionRoot.start_farm_weather_data_fetch_interactor,
          calendar_today: CompositionRoot.calendar_today
        )
        interactor.call(input_dto)
      end

      # GET /api/v1/internal/farms/:farm_id/weather_status
      # 天気データ取得の進捗状況を確認
      def weather_status
        lookup = Adapters::Shared::InternalApiFarmLookup.find_farm(params[:farm_id])
        if lookup[:kind] == :not_found
          return render json: { error: I18n.t("api.errors.common.farm_not_found") }, status: :not_found
        end

        farm = lookup[:farm]

        render json: {
          success: true,
          farm_id: farm.id,
          status: farm.weather_data_status,
          progress: farm.weather_data_progress,
          fetched_blocks: farm.weather_data_fetched_years,
          total_blocks: farm.weather_data_total_years,
          weather_data_count: farm.weather_location&.weather_data&.count || 0,
          last_error: farm.weather_data_last_error
        }
      end

      # GET /api/v1/internal/farms/:farm_id/weather_data
      # 天気データをJSON形式で取得
      def get_weather_data
        lookup = Adapters::Shared::InternalApiFarmLookup.find_farm(params[:farm_id])
        if lookup[:kind] == :not_found
          return render json: { error: I18n.t("api.errors.common.farm_not_found") }, status: :not_found
        end

        farm = lookup[:farm]

        unless farm.weather_location
          return render json: { error: I18n.t("api.errors.common.weather_location_not_found") }, status: :not_found
        end

        weather_data = farm.weather_location.weather_data.order(:date).map do |wd|
          {
            date: wd.date.to_s,
            temperature_max: wd.temperature_max,
            temperature_min: wd.temperature_min,
            temperature_mean: wd.temperature_mean,
            precipitation: wd.precipitation,
            sunshine_hours: wd.sunshine_hours,
            wind_speed: wd.wind_speed,
            weather_code: wd.weather_code
          }
        end

        render json: {
          success: true,
          farm: {
            id: farm.id,
            name: farm.name,
            latitude: farm.latitude,
            longitude: farm.longitude,
            is_reference: farm.is_reference
          },
          weather_location: {
            latitude: farm.weather_location.latitude,
            longitude: farm.weather_location.longitude,
            elevation: farm.weather_location.elevation,
            timezone: farm.weather_location.timezone
          },
          weather_data: weather_data,
          count: weather_data.count
        }
      end

      def render_response(json:, status:)
        render(json: json, status: status)
      end

      private

      def check_environment
        unless Rails.env.development? || Rails.env.test?
          render json: { error: I18n.t("api.errors.common.env_only") },
                 status: :forbidden
        end
      end
    end
  end
end
