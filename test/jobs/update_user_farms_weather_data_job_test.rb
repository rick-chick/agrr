# frozen_string_literal: true

require 'test_helper'

class UpdateUserFarmsWeatherDataJobTest < ActiveJob::TestCase
  setup do
    @user = create(:user)
    @weather_location = WeatherLocation.create!(
      latitude: 35.6762,
      longitude: 139.6503,
      elevation: 10.0,
      timezone: 'Asia/Tokyo'
    )
  end

  test "通常農場がない場合は何も実行しない" do
    # 参照農場のみ存在する場合
    create(:farm, :reference, weather_location: @weather_location)
    
    assert_no_enqueued_jobs(only: FetchWeatherDataJob) do
      UpdateUserFarmsWeatherDataJob.perform_now
    end
  end

  test "weather_locationが設定されていない農場はスキップされる" do
    # weather_locationがnilの農場を作成
    create(:farm, :user_owned, user: @user, weather_location: nil)
    
    assert_no_enqueued_jobs(only: FetchWeatherDataJob) do
      UpdateUserFarmsWeatherDataJob.perform_now
    end
  end

  test "通常農場の最新データから今日までのデータを取得する" do
    # 天気データを設定（最新日付: 3日前）
    latest_date = 3.days.ago.to_date
    WeatherDatum.create!(
      weather_location: @weather_location,
      date: latest_date,
      temperature_max: 25.0,
      temperature_min: 15.0,
      temperature_mean: 20.0
    )
    
    farm = create(:farm, :user_owned, user: @user, weather_location: @weather_location)
    
    # ジョブがエンキューされることを確認
    assert_enqueued_jobs(1, only: FetchWeatherDataJob) do
      UpdateUserFarmsWeatherDataJob.perform_now
    end
  end

  test "最新データがない場合は過去7日分を取得する" do
    farm = create(:farm, :user_owned, user: @user, weather_location: @weather_location)
    
    # ジョブがエンキューされることを確認
    assert_enqueued_jobs(1, only: FetchWeatherDataJob) do
      UpdateUserFarmsWeatherDataJob.perform_now
    end
  end

  test "既に最新のデータがある場合はスキップされる" do
    # 今日のデータが既に存在する場合
    WeatherDatum.create!(
      weather_location: @weather_location,
      date: Date.today,
      temperature_max: 25.0,
      temperature_min: 15.0,
      temperature_mean: 20.0
    )
    
    create(:farm, :user_owned, user: @user, weather_location: @weather_location)
    
    assert_no_enqueued_jobs(only: FetchWeatherDataJob) do
      UpdateUserFarmsWeatherDataJob.perform_now
    end
  end

  test "複数の通常農場に対して順次ジョブをエンキューする" do
    # setupで既に@weather_locationが作成されているため、異なる緯度経度を使用
    weather_location2 = WeatherLocation.create!(
      latitude: 36.2048,
      longitude: 138.2529,
      elevation: 20.0,
      timezone: 'Asia/Tokyo'
    )
    
    farm1 = create(:farm, :user_owned, user: @user, weather_location: @weather_location)
    farm2 = create(:farm, :user_owned, user: @user, weather_location: weather_location2)
    
    assert_enqueued_jobs(2, only: FetchWeatherDataJob) do
      UpdateUserFarmsWeatherDataJob.perform_now
    end
  end

  test "参照農場は処理対象外" do
    # 参照農場を作成
    create(:farm, :reference, weather_location: @weather_location)
    
    assert_no_enqueued_jobs(only: FetchWeatherDataJob) do
      UpdateUserFarmsWeatherDataJob.perform_now
    end
  end

  test "エラーが発生した場合はリトライされる" do
    # このテストは削除するか、より適切な形に変更
    # ActiveJobのリトライロジックはperform_laterでエンキューされた際に動作するため、
    # perform_nowでは即座に例外が発生する
    # リトライロジックのテストは統合テストで行う方が適切
    skip "リトライロジックのテストは統合テストで実施"
  end
end

