# frozen_string_literal: true

# 天気データ管理の共通機能を提供するモジュール（プレーン Ruby。`ActiveSupport::Concern` は使わない）
module WeatherDataManagement
  private

  # 天気データ取得のパラメータを計算
  def calculate_weather_data_params(location)
    result = Domain::WeatherData::Policies::WeatherDataFetchWindowPolicy.fetch_range(
      latest_weather_date: location&.latest_weather_date,
      clock: Time.zone
    )
    if result[:range_adjusted]
      Rails.logger.warn "⚠️ [#{self.class.name}] Start date (#{result[:start_date]}) is after end date before adjustment, adjusting..."
    end
    Rails.logger.info "🌤️ [#{self.class.name}] Weather data period: #{result[:start_date]} to #{result[:end_date]}"
    result.except(:range_adjusted)
  end

  # 天気予測の日数を計算（来年の12月31日まで）
  def calculate_predict_days(end_date)
    predict_days = Domain::WeatherData::Policies::WeatherPredictionHorizonPolicy.predict_days_to_next_year_end(
      end_date: end_date,
      clock: Time.zone
    )
    today = Time.zone.today
    next_year_end = Date.new(today.year + 1, 12, 31)
    Rails.logger.info "📅 [#{self.class.name}] Predict days: #{predict_days} (from #{end_date} to #{next_year_end})"
    predict_days
  end
end
