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
    
    assert_enqueued_jobs(1, only: FetchWeatherDataJob) do
      UpdateUserFarmsWeatherDataJob.perform_now
    end
    
    # エンキューされたジョブの引数を確認
    enqueued_job = enqueued_jobs.find { |j| j[:job] == FetchWeatherDataJob }
    assert_not_nil enqueued_job
    
    args = enqueued_job[:args].first
    assert_equal farm.id, args['farm_id']
    assert_equal (latest_date + 1.day).to_s, args['start_date']
    assert_equal Date.today.to_s, args['end_date']
  end

  test "最新データがない場合は過去7日分を取得する" do
    farm = create(:farm, :user_owned, user: @user, weather_location: @weather_location)
    
    assert_enqueued_jobs(1, only: FetchWeatherDataJob) do
      UpdateUserFarmsWeatherDataJob.perform_now
    end
    
    # エンキューされたジョブの引数を確認
    enqueued_job = enqueued_jobs.find { |j| j[:job] == FetchWeatherDataJob }
    assert_not_nil enqueued_job
    
    args = enqueued_job[:args].first
    assert_equal farm.id, args['farm_id']
    assert_equal (Date.today - 7.days).to_s, args['start_date']
    assert_equal Date.today.to_s, args['end_date']
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
    weather_location1 = WeatherLocation.create!(
      latitude: 35.6762,
      longitude: 139.6503,
      elevation: 10.0,
      timezone: 'Asia/Tokyo'
    )
    weather_location2 = WeatherLocation.create!(
      latitude: 36.2048,
      longitude: 138.2529,
      elevation: 20.0,
      timezone: 'Asia/Tokyo'
    )
    
    farm1 = create(:farm, :user_owned, user: @user, weather_location: weather_location1)
    farm2 = create(:farm, :user_owned, user: @user, weather_location: weather_location2)
    
    assert_enqueued_jobs(2, only: FetchWeatherDataJob) do
      UpdateUserFarmsWeatherDataJob.perform_now
    end
    
    # 各ジョブが適切な間隔でエンキューされていることを確認
    enqueued_jobs_list = enqueued_jobs.select { |j| j[:job] == FetchWeatherDataJob }
    assert_equal 2, enqueued_jobs_list.length
    
    # 最初のジョブは即座に実行
    assert_nil enqueued_jobs_list[0][:at]
    
    # 2番目のジョブは1秒後に実行
    assert_not_nil enqueued_jobs_list[1][:at]
    wait_time = enqueued_jobs_list[1][:at] - Time.current
    assert_in_delta 1.0, wait_time, 0.5
  end

  test "参照農場は処理対象外" do
    # 参照農場を作成
    create(:farm, :reference, weather_location: @weather_location)
    
    assert_no_enqueued_jobs(only: FetchWeatherDataJob) do
      UpdateUserFarmsWeatherDataJob.perform_now
    end
  end

  test "エラーが発生した場合はリトライされる" do
    # データベース接続エラーをシミュレート
    Farm.stub(:user_owned, -> { raise ActiveRecord::ConnectionNotEstablished.new("Connection failed") }) do
      assert_raises(ActiveRecord::ConnectionNotEstablished) do
        UpdateUserFarmsWeatherDataJob.perform_now
      end
    end
  end
end

