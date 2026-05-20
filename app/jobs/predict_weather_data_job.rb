# frozen_string_literal: true

require_relative "concerns/job_arguments_provider"

class PredictWeatherDataJob < ApplicationJob
  include JobArgumentsProvider

  queue_as :default

  # リトライ設定（agrr実行エラー時のみ）
  retry_on Adapters::Agrr::Gateways::BaseGateway::ExecutionError, wait: 5.minutes, attempts: 3
  retry_on Adapters::Agrr::Gateways::BaseGateway::ParseError, wait: 5.minutes, attempts: 3

  # データ不足エラーはリトライしない
  discard_on ArgumentError

  # インスタンス変数の定義
  attr_accessor :farm_id, :days, :model, :target_end_date, :cultivation_plan_id, :channel_class

  # インスタンス変数をハッシュとして返す
  def job_arguments
    {
      farm_id: farm_id,
      days: days,
      model: model,
      target_end_date: target_end_date,
      cultivation_plan_id: cultivation_plan_id,
      channel_class: channel_class
    }
  end

  def perform(farm_id: nil, days: nil, model: nil, target_end_date: nil, cultivation_plan_id: nil, channel_class: nil)
    # dictの中身を確認してバリデーション
    Rails.logger.info "🔍 [PredictWeatherDataJob] Received args: farm_id=#{farm_id}, days=#{days}, model=#{model}, target_end_date=#{target_end_date}, cultivation_plan_id=#{cultivation_plan_id}, channel_class=#{channel_class}"

    # 引数が渡された場合はそれを使用、そうでなければインスタンス変数から取得
    farm_id ||= self.farm_id
    days ||= self.days
    model ||= self.model
    target_end_date ||= self.target_end_date
    cultivation_plan_id ||= self.cultivation_plan_id
    channel_class ||= self.channel_class

    phase_predicting_weather_started = false

    farm = Farm.find_by(id: farm_id)
    unless farm
      error_message = "Farm ##{farm_id} not found"
      Rails.logger.error "❌ [PredictWeatherDataJob] #{error_message}"
      raise ActiveRecord::RecordNotFound, error_message
    end

    # 予測開始通知
    if cultivation_plan_id && channel_class
      cultivation_plan = CultivationPlan.find_by(id: cultivation_plan_id)
      unless cultivation_plan
        error_message = "CultivationPlan ##{cultivation_plan_id} not found for weather prediction start"
        Rails.logger.error "❌ [PredictWeatherDataJob] #{error_message}"
        raise ActiveRecord::RecordNotFound, error_message
      end

      cultivation_plan.phase_predicting_weather!(channel_class)
      phase_predicting_weather_started = true
      Rails.logger.info "🌤️ [PredictWeatherDataJob] Started weather prediction for plan ##{cultivation_plan_id}"
    end

    # target_end_dateが指定されていない場合、今日から1年後に設定
    # （過去1年のデータと対称的に表示するため）
    if target_end_date.nil?
      target_end_date = Date.today + 1.year
    end

    Rails.logger.info "🔮 [PredictWeatherDataJob] Starting prediction for Farm ##{farm_id} (target: #{target_end_date})"

    # Farmに関連付けられたWeatherLocationを使用
    weather_location = farm.weather_location

    if weather_location.nil?
      error_message = "Farm ##{farm_id} has no weather_location association"
      Rails.logger.error "❌ [PredictWeatherDataJob] #{error_message}"
      raise ArgumentError, error_message
    end

    # 過去20年分のデータを取得（予測のための履歴データ）
    # 長期予測の精度向上のため、十分な学習データを使用
    # 最新のデータが古い場合も考慮して、利用可能な最新データまでを使用
    latest_available_date = weather_location.weather_data.maximum(:date)

    if latest_available_date.nil?
      error_message = "Farm ##{farm_id} has no weather data for prediction"
      Rails.logger.error "❌ [PredictWeatherDataJob] #{error_message}"
      raise ArgumentError, error_message
    end

    end_date = latest_available_date
    start_date = end_date - 20.years

    # 予測開始日を決定：今日または履歴データの翌日のいずれか新しい方
    prediction_start_date = [ Date.today, end_date + 1.day ].max

    # 予測終了日までの日数を計算
    # AGRRは履歴データの最終日から予測を開始するため、
    # 履歴データの最終日からtarget_end_dateまでの日数を計算する
    if days.nil?
      # 履歴データの翌日からtarget_end_dateまでの日数
      days = (target_end_date - end_date).to_i
    end

    Rails.logger.info "📊 [PredictWeatherDataJob] Using historical data from #{start_date} to #{end_date} (latest available: #{latest_available_date})"
    Rails.logger.info "📊 [PredictWeatherDataJob] Prediction period: #{prediction_start_date} to #{target_end_date} (#{days} days)"

    historical_data = weather_location.weather_data
      .where(date: start_date..end_date)
      .order(:date)
      .select(:date, :temperature_max, :temperature_min, :temperature_mean, :precipitation)

    if historical_data.empty?
      error_message = "Farm ##{farm_id} has insufficient historical weather data for prediction"
      Rails.logger.error "❌ [PredictWeatherDataJob] #{error_message}"
      raise ArgumentError, error_message
    end

    # 履歴データをPredictionGateway用のフォーマットに変換
    # 地域特性を学習するために座標情報を含める
    formatted_data = {
      "latitude" => weather_location.latitude.to_f,
      "longitude" => weather_location.longitude.to_f,
      "elevation" => (weather_location.elevation || 0.0).to_f,
      "timezone" => weather_location.timezone || "UTC",
      "data" => historical_data.filter_map do |datum|
        # 温度データが欠損しているレコードをスキップ
        next if datum.temperature_max.nil? || datum.temperature_min.nil?

        # temperature_meanがNULLの場合は max/min から計算
        temp_mean = datum.temperature_mean
        if temp_mean.nil?
          temp_mean = (datum.temperature_max + datum.temperature_min) / 2.0
        end

        {
          "time" => datum.date.to_s,
          "temperature_2m_max" => datum.temperature_max.to_f,
          "temperature_2m_min" => datum.temperature_min.to_f,
          "temperature_2m_mean" => temp_mean.to_f,
          "precipitation_sum" => (datum.precipitation || 0.0).to_f
        }
      end
    }

    Rails.logger.info "📍 [PredictWeatherDataJob] Location: (#{weather_location.latitude}, #{weather_location.longitude}), elevation: #{weather_location.elevation}m, timezone: #{weather_location.timezone}"

    # PredictionGatewayを使って予測を実行（daemon経由で高速実行）
    prediction_gateway = Adapters::Agrr::Gateways::PredictionGateway.new

    prediction_result = prediction_gateway.predict(
      historical_data: formatted_data,
      days: days,
      model: model
    )

    # 予測データを整形してFarmに保存
    # 予測開始日以降のデータのみをフィルタリング
    prediction_data = prediction_result["data"].filter_map do |datum|
      datum_date = Date.parse(datum["time"])

      # 過去のデータはスキップ（prediction_start_dateより前のデータ）
      next if datum_date < prediction_start_date

      # 温度データが欠損している場合もスキップ
      temp_max = datum["temperature_2m_max"]
      temp_min = datum["temperature_2m_min"]
      next if temp_max.nil? || temp_min.nil?

      # temperature_meanがnilの場合は計算
      temp_mean = datum["temperature_2m_mean"]
      temp_mean = (temp_max + temp_min) / 2.0 if temp_mean.nil?

      {
        date: datum["time"],
        temperature_max: temp_max.to_f,
        temperature_min: temp_min.to_f,
        temperature_mean: temp_mean.to_f,
        precipitation: (datum["precipitation_sum"] || 0.0).to_f,
        is_prediction: true
      }
    end

    Rails.logger.info "📊 [PredictWeatherDataJob] Filtered prediction data: #{prediction_data.count} records (#{prediction_start_date} to #{target_end_date})"

    # Farmの予測データを更新
    farm.update!(
      predicted_weather_data: {
        "data" => prediction_data,
        "prediction_start_date" => prediction_start_date.to_s,
        "prediction_end_date" => target_end_date.to_s,
        "predicted_at" => Time.current.iso8601,
        "model" => model
      }
    )

    Rails.logger.info "✅ [PredictWeatherDataJob] Completed for Farm ##{farm_id}: #{prediction_data.count} days predicted"

    # 予測完了通知
    if cultivation_plan_id && channel_class
      cultivation_plan = CultivationPlan.find_by(id: cultivation_plan_id)
      unless cultivation_plan
        error_message = "CultivationPlan ##{cultivation_plan_id} not found for weather prediction completion"
        Rails.logger.error "❌ [PredictWeatherDataJob] #{error_message}"
        raise ActiveRecord::RecordNotFound, error_message
      end

      cultivation_plan.phase_weather_prediction_completed!(channel_class)
      Rails.logger.info "🌤️ [PredictWeatherDataJob] Weather prediction completed for plan ##{cultivation_plan_id}"
    end

    # WebSocketで完了を通知
    broadcast_completion(farm, prediction_data.count)
  ensure
    exception = $!
    if exception &&
        phase_predicting_weather_started &&
        cultivation_plan_id &&
        channel_class &&
        !exception.is_a?(ActiveRecord::RecordNotFound) &&
        !exception.is_a?(Adapters::Agrr::Gateways::BaseGateway::ExecutionError) &&
        !exception.is_a?(Adapters::Agrr::Gateways::BaseGateway::ParseError)
      cp = CultivationPlan.find_by(id: cultivation_plan_id)
      if cp
        phase_failed_notified = false
        suppress(StandardError) do
          cp.phase_failed!("predicting_weather", channel_class)
          phase_failed_notified = true
        end
        if phase_failed_notified
          Rails.logger.info "🌤️ [PredictWeatherDataJob] Weather prediction failed for plan ##{cultivation_plan_id}"
        else
          Rails.logger.error "❌ [PredictWeatherDataJob] Failed to notify phase failure (see Solid Queue / logs)"
        end
      end
    end
  end

  private

  def broadcast_completion(farm, prediction_count)
    stream_name = "prediction:#{farm.to_gid_param}"

    broadcast_ok = false
    suppress(StandardError) do
      ActionCable.server.broadcast(
        stream_name,
        {
          type: "prediction_completed",
          farm_id: farm.id,
          data_count: prediction_count,
          prediction_start_date: farm.predicted_weather_data["prediction_start_date"],
          prediction_end_date: farm.predicted_weather_data["prediction_end_date"],
          message: "予測が完了しました",
          message_key: "jobs.prediction.completed"
        }
      )
      Rails.logger.info "📡 [PredictWeatherDataJob] Broadcasted completion to #{stream_name}"
      broadcast_ok = true
    end

    return if broadcast_ok

    Rails.logger.error "❌ Broadcast completion failed for Farm ##{farm.id}"
  end
end
