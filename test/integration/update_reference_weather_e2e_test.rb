# frozen_string_literal: true

require "test_helper"

class UpdateReferenceWeatherE2eTest < ActiveJob::TestCase
  setup do
    # 既存の参照農場を削除
    Farm.where(is_reference: true).destroy_all

    # アノニマスユーザーを取得
    @anonymous_user = User.anonymous_user

    # テスト用参照農場を作成（47都道府県のうち3件をサンプルとして）
    @farms = [
      { name: "北海道", lat: 43.0642, lon: 141.3469 },
      { name: "東京", lat: 35.6762, lon: 139.6503 },
      { name: "沖縄", lat: 26.2124, lon: 127.6809 }
    ].map do |data|
      Farm.create!(
        name: data[:name],
        user: @anonymous_user,
        latitude: data[:lat],
        longitude: data[:lon],
        is_reference: true
      )
    end

    # ジョブキューをクリア
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
    ActiveJob::Base.queue_adapter.performed_jobs.clear
  end

  test "E2E: UpdateReferenceWeatherDataJob enqueues jobs for all reference farms" do
    # 【1. 事前状態の確認】
    reference_farms_count = Farm.reference.where.not(latitude: nil, longitude: nil).count
    assert_equal 3, reference_farms_count, "参照農場が3件作成されているべき"

    # 【2. ジョブ実行】
    start_time = Time.current
    
    assert_enqueued_jobs reference_farms_count, only: FetchWeatherDataJob do
      UpdateReferenceWeatherDataJob.perform_now
    end
    
    elapsed_time = Time.current - start_time
    
    # 【3. パフォーマンス確認】
    max_time = 1.0  # 1秒以内に完了すべき
    assert elapsed_time < max_time,
      "実行時間が長すぎます: #{elapsed_time.round(2)}秒 (最大: #{max_time}秒)"

    # 【4. エンキューされたジョブの詳細確認】
    enqueued_jobs = ActiveJob::Base.queue_adapter.enqueued_jobs.select do |job|
      job[:job] == FetchWeatherDataJob
    end

    assert_equal reference_farms_count, enqueued_jobs.size,
      "すべての参照農場のジョブがエンキューされているべき"

    # 【5. 日付範囲の確認】
    expected_start_date = Time.zone.today - UpdateReferenceWeatherDataJob::WEATHER_DATA_LOOKBACK_DAYS.days
    expected_end_date = Time.zone.today

    enqueued_jobs.each do |job|
      job_args = job[:args].find { |arg| arg.is_a?(Hash) }
      
      start_date_value = job_args["start_date"].is_a?(Hash) ? 
        Date.parse(job_args["start_date"]["value"]) : 
        job_args["start_date"]
      end_date_value = job_args["end_date"].is_a?(Hash) ? 
        Date.parse(job_args["end_date"]["value"]) : 
        job_args["end_date"]
      
      assert_equal expected_start_date, start_date_value,
        "開始日が正しくないです"
      assert_equal expected_end_date, end_date_value,
        "終了日が正しくないです"
    end

    # 【6. farm_idの確認】
    enqueued_farm_ids = enqueued_jobs.map do |job|
      job[:args].find { |arg| arg.is_a?(Hash) && arg.key?("farm_id") }&.dig("farm_id")
    end.compact

    @farms.each do |farm|
      assert_includes enqueued_farm_ids, farm.id,
        "Farm##{farm.id} (#{farm.name}) のジョブがエンキューされているべき"
    end

    # 【7. 待機時間の確認（API負荷軽減）】
    # ジョブの待機時間が設定されていることを確認
    enqueued_jobs.each_with_index do |job, index|
      if index > 0
        # 2番目以降のジョブには待機時間が設定されているべき
        assert job[:at].present?,
          "ジョブ#{index + 1}には待機時間が設定されているべき"
      end
    end
  end

  test "E2E: correctly uses defined constants" do
    # 定数が正しく定義されていることを確認
    assert_equal 7, UpdateReferenceWeatherDataJob::WEATHER_DATA_LOOKBACK_DAYS,
      "WEATHER_DATA_LOOKBACK_DAYS は7であるべき"
    assert_equal 1.0, UpdateReferenceWeatherDataJob::API_INTERVAL_SECONDS,
      "API_INTERVAL_SECONDS は1.0であるべき"
  end

  test "E2E: handles empty reference farms gracefully" do
    # すべての参照農場を削除
    Farm.where(is_reference: true).destroy_all

    # ジョブが0件エンキューされることを確認
    assert_enqueued_jobs 0, only: FetchWeatherDataJob do
      UpdateReferenceWeatherDataJob.perform_now
    end

    # エラーが発生しないことを確認
    assert_nothing_raised do
      UpdateReferenceWeatherDataJob.perform_now
    end
  end

  test "E2E: skips farms without coordinates" do
    # 座標のない参照農場を作成
    invalid_farm = Farm.new(
      name: "座標なし農場",
      user: @anonymous_user,
      is_reference: true
    )
    invalid_farm.save(validate: false)

    # 有効な3件のみジョブがエンキューされる
    assert_enqueued_jobs 3, only: FetchWeatherDataJob do
      UpdateReferenceWeatherDataJob.perform_now
    end
  end

  test "E2E: performance meets requirements" do
    # パフォーマンス要件
    # - 3件の農場で1秒以内に完了すべき
    
    start_time = Time.current
    
    UpdateReferenceWeatherDataJob.perform_now
    
    elapsed_time = Time.current - start_time
    
    assert elapsed_time < 1.0,
      "パフォーマンス要件を満たしていません: #{elapsed_time.round(2)}秒 (要件: < 1.0秒)"
  end
end

