# frozen_string_literal: true

require_relative 'concerns/job_arguments_provider'

class WeatherPredictionJob < ApplicationJob
  include JobArgumentsProvider
  
  queue_as :default
  
  # インスタンス変数の定義
  attr_accessor :cultivation_plan_id, :channel_class, :predict_days
  
  # インスタンス変数をハッシュとして返す
  def job_arguments
    {
      cultivation_plan_id: cultivation_plan_id,
      channel_class: channel_class,
      predict_days: predict_days
    }
  end
  
  def perform(cultivation_plan_id: nil, channel_class: nil, predict_days: nil)
    # dictの中身を確認してバリデーション
    Rails.logger.info "🔍 [WeatherPredictionJob] Received args: cultivation_plan_id=#{cultivation_plan_id}, channel_class=#{channel_class}, predict_days=#{predict_days}"
    
    # 引数が渡された場合はそれを使用、そうでなければインスタンス変数から取得
    cultivation_plan_id ||= self.cultivation_plan_id
    channel_class ||= self.channel_class
    predict_days ||= self.predict_days
    
    cultivation_plan = CultivationPlan.find(cultivation_plan_id)
    
    Rails.logger.info "🌤️ [WeatherPredictionJob] Starting weather prediction for plan ##{cultivation_plan_id}"
    
    begin
      # 天気予測開始通知
      Rails.logger.info "🌤️ [WeatherPredictionJob] Calling phase_predicting_weather! for plan ##{cultivation_plan_id}"
      cultivation_plan.phase_predicting_weather!(channel_class)
      Rails.logger.info "🌤️ [WeatherPredictionJob] phase_predicting_weather! completed for plan ##{cultivation_plan_id}"
      
      # 天気予測処理
      Rails.logger.info "🌤️ [WeatherPredictionJob] Starting weather prediction service for plan ##{cultivation_plan_id}"
      weather_prediction_service = WeatherPredictionService.new(cultivation_plan.farm)
      weather_prediction_service.predict_for_cultivation_plan(cultivation_plan)
      
      # 天気予測完了通知
      Rails.logger.info "🌤️ [WeatherPredictionJob] Calling phase_weather_prediction_completed! for plan ##{cultivation_plan_id}"
      cultivation_plan.phase_weather_prediction_completed!(channel_class)
      
      Rails.logger.info "✅ [WeatherPredictionJob] Weather prediction completed for plan ##{cultivation_plan_id}"
      
    rescue => e
      Rails.logger.error "❌ [WeatherPredictionJob] Failed to predict weather for plan ##{cultivation_plan_id}: #{e.message}"
      cultivation_plan.phase_failed!('predicting_weather', channel_class)
      raise
    end
  end
end
