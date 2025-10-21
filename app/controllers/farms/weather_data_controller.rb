# frozen_string_literal: true

module Farms
  class WeatherDataController < ApplicationController
    before_action :set_farm

    # GET /farms/:farm_id/weather_data
    # パラメータ: start_date, end_date (オプション), predict (オプション)
    def index
      # 予測モードの場合
      if params[:predict] == 'true'
        return predict_weather_data
      end

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
          message: t('farms.weather_data.no_weather_data'),
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

      # JSON形式で返す（null値を持つレコードはフィルタリング）
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
        data: weather_data.filter_map do |datum|
          # 温度データが欠損している場合はスキップ
          next if datum.temperature_max.nil? || datum.temperature_min.nil?
          
          # temperature_meanがnilの場合は計算
          temp_mean = datum.temperature_mean
          temp_mean = (datum.temperature_max + datum.temperature_min) / 2.0 if temp_mean.nil?
          
          {
            date: datum.date,
            temperature_max: datum.temperature_max.to_f,
            temperature_min: datum.temperature_min.to_f,
            temperature_mean: temp_mean.to_f,
            precipitation: (datum.precipitation || 0.0).to_f
          }
        end
      }
    end

    private

    def predict_weather_data
      Rails.logger.info "🔮 Weather prediction request for Farm##{@farm.id}"
      
      # 既に予測データが保存されているかチェック
      if @farm.predicted_weather_data.present? && @farm.predicted_weather_data['data'].present?
        prediction_data = @farm.predicted_weather_data
        
        Rails.logger.info "✅ [Farm##{@farm.id}] Returning cached prediction data (#{prediction_data['data'].count} days)"
        
        # 予測データからnull値を除外
        filtered_data = prediction_data['data'].filter_map do |datum|
          # 温度データが欠損している場合はスキップ
          next if datum['temperature_max'].nil? || datum['temperature_min'].nil?
          
          # temperature_meanがnilの場合は計算
          temp_mean = datum['temperature_mean']
          temp_mean = (datum['temperature_max'] + datum['temperature_min']) / 2.0 if temp_mean.nil?
          
          {
            date: datum['date'],
            temperature_max: datum['temperature_max'].to_f,
            temperature_min: datum['temperature_min'].to_f,
            temperature_mean: temp_mean.to_f,
            precipitation: (datum['precipitation'] || 0.0).to_f
          }
        end
        
        render json: {
          success: true,
          farm: {
            id: @farm.id,
            name: @farm.display_name,
            latitude: @farm.latitude,
            longitude: @farm.longitude
          },
          period: {
            start_date: prediction_data['prediction_start_date'],
            end_date: prediction_data['prediction_end_date']
          },
          is_prediction: true,
          predicted_at: prediction_data['predicted_at'],
          model: prediction_data['model'],
          data: filtered_data
        }
        return
      end
      
      # 予測データがない場合は、バックグラウンドジョブを開始
      # Farmに関連付けられたWeatherLocationを使用
      weather_location = @farm.weather_location
      
      if weather_location.nil?
        Rails.logger.warn "⚠️  Farm##{@farm.id} has no weather_location association"
        weather_location = find_weather_location_for_farm(@farm)
      end
      
      if weather_location.nil?
        render json: {
          success: false,
          message: t('farms.weather_data.no_weather_data')
        }
        return
      end
      
      # 過去2年分のデータがあるか確認
      end_date = Date.today
      start_date = end_date - 2.years
      
      historical_data_count = weather_location.weather_data
        .where(date: start_date..end_date)
        .where.not(temperature_max: nil, temperature_min: nil)
        .count
      
      if historical_data_count < 365
        render json: {
          success: false,
          message: t('farms.weather_data.insufficient_historical_data')
        }
        return
      end
      
      # バックグラウンドジョブとしてキューに入れる（daemon経由で高速実行）
      # 来年の12/31までの日数を自動計算（nilを渡すとジョブ側で計算）
      begin
        PredictWeatherDataJob.perform_later(
          farm_id: @farm.id,
          days: nil,  # 来年の12/31まで（ジョブ側で自動計算）
          model: 'lightgbm'
        )
        
        Rails.logger.info "✅ [Farm##{@farm.id}] Weather prediction job queued"
        
        render json: {
          success: true,
          message: t('farms.weather_section.prediction_job_started'),
          farm: {
            id: @farm.id,
            name: @farm.display_name
          },
          status: 'processing'
        }
      rescue => e
        Rails.logger.error "❌ Failed to queue prediction job for Farm##{@farm.id}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        
        render json: {
          success: false,
          message: t('farms.weather_data.job_queue_failed', error: e.message)
        }, status: :internal_server_error
      end
    end

    def set_farm
      if admin_user?
        @farm = Farm.find(params[:farm_id])
      else
        @farm = current_user.farms.find(params[:farm_id])
      end
    rescue ActiveRecord::RecordNotFound
      render json: { 
        success: false, 
        message: t('farms.weather_data.farm_not_found')
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

