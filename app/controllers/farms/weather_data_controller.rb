# frozen_string_literal: true

module Farms
  class WeatherDataController < ApplicationController
    before_action :set_farm

    # GET /farms/:farm_id/weather_data
    # パラメータ: start_date, end_date (オプション)
    def index
      # デフォルトで過去1年間のデータを取得
      end_date = params[:end_date]&.to_date || Date.today
      start_date = params[:start_date]&.to_date || (end_date - 1.year)

      Rails.logger.info "🔍 Weather data request for Farm##{@farm.id} (#{@farm.latitude}, #{@farm.longitude})"
      Rails.logger.info "   Period: #{start_date} to #{end_date}"

      # Farmに直接関連付けられたWeatherLocationを使用
      weather_location = @farm.weather_location

      # 関連付けがない場合は、座標から検索（後方互換性のため）
      if weather_location.nil?
        Rails.logger.warn "⚠️  Farm##{@farm.id} has no weather_location association, trying coordinate search..."
        weather_location = find_weather_location_for_farm(@farm)
      end

      if weather_location.nil?
        Rails.logger.warn "❌ No WeatherLocation found for Farm##{@farm.id}"
        Rails.logger.warn "   Farm coordinates: (#{@farm.latitude}, #{@farm.longitude})"
        Rails.logger.warn "   Total WeatherLocations in DB: #{WeatherLocation.count}"
        
        render json: { 
          success: false, 
          message: 'この農場の天気データがまだ取得されていません。',
          debug: {
            farm_id: @farm.id,
            farm_coordinates: { latitude: @farm.latitude, longitude: @farm.longitude },
            weather_locations_count: WeatherLocation.count,
            has_weather_location_association: @farm.weather_location_id.present?
          }
        }
        return
      end

      Rails.logger.info "✅ Found WeatherLocation##{weather_location.id}"

      # 指定期間の天気データを取得（countの前にselectしない）
      weather_data_relation = weather_location.weather_data
        .where(date: start_date..end_date)
        .order(:date)
      
      data_count = weather_data_relation.count
      Rails.logger.info "   Found #{data_count} weather records"
      
      if data_count.zero?
        Rails.logger.warn "⚠️  No weather data in the requested period"
        total_data = weather_location.weather_data.count
        if total_data > 0
          earliest = weather_location.weather_data.order(:date).first
          latest = weather_location.weather_data.order(:date).last
          Rails.logger.info "   Available data period: #{earliest.date} to #{latest.date}"
        end
      end
      
      # データ取得時にselectを適用
      weather_data = weather_data_relation.select(:date, :temperature_max, :temperature_min, :temperature_mean, :precipitation)

      # JSON形式で返す
      render json: {
        success: true,
        farm: {
          id: @farm.id,
          name: @farm.display_name,
          latitude: @farm.latitude,
          longitude: @farm.longitude
        },
        period: {
          start_date: start_date,
          end_date: end_date
        },
        data: weather_data.map do |datum|
          {
            date: datum.date,
            temperature_max: datum.temperature_max,
            temperature_min: datum.temperature_min,
            temperature_mean: datum.temperature_mean,
            precipitation: datum.precipitation
          }
        end
      }
    end

    private

    def set_farm
      if admin_user?
        @farm = Farm.find(params[:farm_id])
      else
        @farm = current_user.farms.find(params[:farm_id])
      end
    rescue ActiveRecord::RecordNotFound
      render json: { 
        success: false, 
        message: '指定された農場が見つかりません。' 
      }, status: :not_found
    end

    # 農場の座標に最も近いWeatherLocationを探す
    # 天気APIが返す座標は農場の座標と異なる可能性があるため
    def find_weather_location_for_farm(farm)
      # まず完全一致を試す
      location = WeatherLocation.find_by(
        latitude: farm.latitude,
        longitude: farm.longitude
      )
      return location if location

      # 完全一致しない場合、近似マッチング（0.01度 ≈ 1.1km の範囲内で最も近いものを選択）
      tolerance = 0.01
      WeatherLocation.where(
        'ABS(latitude - ?) < ? AND ABS(longitude - ?) < ?',
        farm.latitude, tolerance,
        farm.longitude, tolerance
      ).order(
        Arel.sql("(ABS(latitude - #{farm.latitude.to_f}) + ABS(longitude - #{farm.longitude.to_f}))")
      ).first
    end
  end
end

