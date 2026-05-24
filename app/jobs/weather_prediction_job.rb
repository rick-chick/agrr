# frozen_string_literal: true

require_relative "concerns/job_arguments_provider"

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

    CompositionRoot.advance_cultivation_plan_phase(
      plan_id: cultivation_plan_id,
      phase_name: :phase_predicting_weather,
      channel_class: channel_class
    )

    # 天気予測処理
    Rails.logger.info "🌤️ [WeatherPredictionJob] Starting weather prediction service for plan ##{cultivation_plan_id}"
    weather_location = cultivation_plan.farm&.weather_location
    unless weather_location
      raise Domain::WeatherData::Interactors::WeatherPredictionInteractor::WeatherDataNotFoundError,
            "気象データがありません。農場にWeatherLocationが設定されていません。"
    end
    weather_prediction_service = CompositionRoot.weather_prediction_interactor(weather_location: weather_location, farm: cultivation_plan.farm)
    weather_prediction_service.predict_for_cultivation_plan(
      plan_weather: CompositionRoot.cultivation_plan_weather_dto_from(cultivation_plan)
    )

    # 天気予測完了通知
    CompositionRoot.advance_cultivation_plan_phase(
      plan_id: cultivation_plan_id,
      phase_name: :phase_weather_prediction_completed,
      channel_class: channel_class
    )

    Rails.logger.info "✅ [WeatherPredictionJob] Weather prediction completed for plan ##{cultivation_plan_id}"
  rescue *(CultivationPlanJobExceptions::WEATHER_PREDICTION_FAILURES) => e
    Rails.logger.error "❌ [WeatherPredictionJob] Failed to predict weather for plan ##{cultivation_plan_id}: #{e.message}"
    CompositionRoot.advance_cultivation_plan_phase(
      plan_id: cultivation_plan_id,
      phase_name: :phase_failed,
      channel_class: channel_class,
      failure_subphase: "predicting_weather"
    )
    raise
  end
end
