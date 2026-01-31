# frozen_string_literal: true

# 天気データ管理の共通機能を提供するConcern
module WeatherDataManagement
  extend ActiveSupport::Concern
  
  private
  
  # 天気データ取得のパラメータを計算
  def calculate_weather_data_params(location)
    # 開始日: 今日から20年前
    start_date = Date.current - 20.years
    
    # 終了日: 予測に必要な「今日の2日前」まで必ず取得する。
    # latest_weather_date が古い場合でも current year データを取得するため、下限を Date.current - 2.days とする。
    minimum_end = Date.current - 2.days
    end_date = [
      location&.latest_weather_date,
      minimum_end
    ].compact.max
    
    # 開始日が終了日より後の場合は調整
    if start_date > end_date
      Rails.logger.warn "⚠️ [#{self.class.name}] Start date (#{start_date}) is after end date (#{end_date}), adjusting..."
      end_date = start_date + 1.day
    end
    
    Rails.logger.info "🌤️ [#{self.class.name}] Weather data period: #{start_date} to #{end_date}"
    
    {
      start_date: start_date,
      end_date: end_date
    }
  end
  
  # 天気予測の日数を計算（来年の12月31日まで）
  def calculate_predict_days(end_date)
    # 来年の12月31日を予測終了日として設定
    next_year_end = Date.new(Date.current.year + 1, 12, 31)
    
    # 終了日から来年の12月31日までの日数を計算
    predict_days = (next_year_end - end_date).to_i
    
    Rails.logger.info "📅 [#{self.class.name}] Predict days: #{predict_days} (from #{end_date} to #{next_year_end})"
    predict_days
  end
end
