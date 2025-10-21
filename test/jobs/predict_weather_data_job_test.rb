# frozen_string_literal: true

require 'test_helper'

class PredictWeatherDataJobTest < ActiveJob::TestCase
  setup do
    @farm = farms(:one)
    
    # WeatherLocationを作成
    @weather_location = WeatherLocation.create!(
      latitude: @farm.latitude,
      longitude: @farm.longitude,
      elevation: 40.0,
      timezone: 'Asia/Tokyo'
    )
    @farm.update!(weather_location: @weather_location)
    
    # 過去2年分のモックデータを作成（テスト用）
    # 注: 実際の予測には20年分必要だが、テストはジョブのキューイングとエラー処理のみ確認
    start_date = Date.today - 2.years
    end_date = Date.today
    
    (start_date..end_date).each do |date|
      WeatherDatum.create!(
        weather_location: @weather_location,
        date: date,
        temperature_max: 25.0 + rand(-5.0..5.0),
        temperature_min: 15.0 + rand(-5.0..5.0),
        temperature_mean: 20.0 + rand(-5.0..5.0),
        precipitation: rand(0.0..10.0)
      )
    end
  end
  
  teardown do
    # テストデータをクリーンアップ
    WeatherDatum.where(weather_location: @weather_location).delete_all
  end
  
  test 'should be enqueued successfully' do
    assert_enqueued_jobs 1, only: PredictWeatherDataJob do
      PredictWeatherDataJob.perform_later(
        farm_id: @farm.id,
        days: nil,  # 来年の12/31まで自動計算
        model: 'lightgbm'
      )
    end
  end
  
  test 'should require farm with weather location' do
    farm_without_location = farms(:two)
    farm_without_location.update!(weather_location: nil)
    
    assert_raises(ArgumentError) do
      PredictWeatherDataJob.perform_now(
        farm_id: farm_without_location.id,
        days: nil,  # 来年の12/31まで自動計算
        model: 'lightgbm'
      )
    end
  end
  
  test 'should require sufficient historical data' do
    # 履歴データを削除
    WeatherDatum.where(weather_location: @weather_location).delete_all
    
    assert_raises(ArgumentError) do
      PredictWeatherDataJob.perform_now(
        farm_id: @farm.id,
        days: nil,  # 来年の12/31まで自動計算
        model: 'lightgbm'
      )
    end
  end
end

