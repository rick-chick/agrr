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

      # Farmに関連付けられたWeatherLocationを使用
      weather_location = @farm.weather_location

      if weather_location.nil?
        Rails.logger.error "❌ Farm##{@farm.id} has no weather_location association"
        render json: { 
          success: false, 
          message: t('farms.weather_data.no_weather_data')
        }, status: :not_found
        return
      end

      Rails.logger.info "✅ Using WeatherLocation##{weather_location.id} for Farm##{@farm.id}"

      data_count = weather_data_gateway.weather_data_count(
        weather_location_id: weather_location.id,
        start_date: start_date,
        end_date: end_date
      )
      Rails.logger.info "   Found #{data_count} weather records"
      
      if data_count.zero?
        Rails.logger.warn "⚠️  No weather data in the requested period"
        total_data = weather_data_gateway.weather_data_count(weather_location_id: weather_location.id)
        if total_data > 0
          earliest_date = weather_data_gateway.earliest_date(weather_location_id: weather_location.id)
          latest_date = weather_data_gateway.latest_date(weather_location_id: weather_location.id)
          Rails.logger.info "   Available data period: #{earliest_date} to #{latest_date}"
        end
      end
      
      # データ取得時にselectを適用
      weather_data_dtos = weather_data_gateway.weather_data_for_period(
        weather_location_id: weather_location.id,
        start_date: start_date,
        end_date: end_date
      )
      weather_data = weather_data_dtos.map do |dto|
        {
          date: dto.date,
          temperature_max: dto.temperature_max,
          temperature_min: dto.temperature_min,
          temperature_mean: dto.temperature_mean,
          precipitation: dto.precipitation
        }
      end

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
        predicted_at = Time.zone.parse(prediction_data['predicted_at']) rescue nil
        
        # 予測データが古い場合は再予測（24時間以上経過、または予測開始日が過去になった場合）
        is_outdated = predicted_at.nil? || 
                      (Time.current - predicted_at) > 24.hours ||
                      Date.parse(prediction_data['prediction_start_date']) < Date.today
        
        if is_outdated
          Rails.logger.info "⚠️ [Farm##{@farm.id}] Prediction data is outdated (predicted_at: #{predicted_at}), re-predicting..."
          # 古い予測データを削除して再予測（以下のコードに進む）
          @farm.update!(predicted_weather_data: nil)
        else
          Rails.logger.info "✅ [Farm##{@farm.id}] Returning cached prediction data (#{prediction_data['data'].count} days, predicted_at: #{predicted_at})"
          
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
      end
      
      # 予測データがない場合は、バックグラウンドジョブを開始
      # Farmに関連付けられたWeatherLocationを使用
      weather_location = @farm.weather_location
      
      if weather_location.nil?
        Rails.logger.error "❌ Farm##{@farm.id} has no weather_location association"
        render json: {
          success: false,
          message: t('farms.weather_data.no_weather_data')
        }, status: :not_found
        return
      end
      
      # 過去2年分のデータがあるか確認（閏年を考慮し日数で判定）
      end_date = Date.today
      start_date = end_date - 2.years
      
      historical_data_count = weather_data_gateway.historical_data_count(weather_location_id: weather_location.id, start_date: start_date, end_date: end_date)
      
      required_days = (start_date.to_date..end_date.to_date).count
      if historical_data_count < required_days
        render json: {
          success: false,
          message: t('farms.weather_data.insufficient_historical_data')
        }, status: :unprocessable_entity
        return
      end
      
      # バックグラウンドジョブとしてキューに入れる（daemon経由で高速実行）
      # 1年後までの日数を自動計算（nilを渡すとジョブ側で計算）
      begin
        # 農場単体での天気予測実行（計画作成とは独立）
        # WebSocket通知は不要（単独実行のため）
        PredictWeatherDataJob.perform_later(
          farm_id: @farm.id,
          days: nil,  # 1年後まで（ジョブ側で自動計算）
          model: 'lightgbm',
          target_end_date: nil,  # ジョブ側で自動計算
          cultivation_plan_id: nil,  # 単独実行のため nil
          channel_class: nil  # 単独実行のため nil
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

    def weather_data_gateway
      @weather_data_gateway ||= Adapters::WeatherData::Gateways::ActiveRecordWeatherDataGateway.new
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
  end
end

