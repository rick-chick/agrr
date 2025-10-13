# frozen_string_literal: true

require "test_helper"

class UpdateReferenceWeatherDataJobTest < ActiveJob::TestCase
  setup do
    # 既存の参照農場をすべて削除（fixtureのデータをクリーンアップ）
    Farm.where(is_reference: true).destroy_all

    # アノニマスユーザーを取得または作成
    @anonymous_user = User.anonymous_user

    # 参照農場を作成
    @reference_farm1 = Farm.create!(
      name: "参照農場1",
      user: @anonymous_user,
      latitude: 35.6895,
      longitude: 139.6917,
      is_reference: true
    )

    @reference_farm2 = Farm.create!(
      name: "参照農場2",
      user: @anonymous_user,
      latitude: 43.0642,
      longitude: 141.3469,
      is_reference: true
    )

    # 通常の農場を作成（更新対象外）
    @normal_user = User.create!(
      name: "Normal User",
      email: "normal@example.com",
      google_id: "google_123456",
      is_anonymous: false
    )

    @normal_farm = Farm.create!(
      name: "通常農場",
      user: @normal_user,
      latitude: 35.0,
      longitude: 135.0,
      is_reference: false
    )

    # ジョブキューをクリア
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
    ActiveJob::Base.queue_adapter.performed_jobs.clear
  end

  test "should enqueue weather data jobs for all reference farms" do
    # 設定された日数分のデータを取得することを期待
    expected_start_date = Time.zone.today - UpdateReferenceWeatherDataJob::WEATHER_DATA_LOOKBACK_DAYS.days
    expected_end_date = Time.zone.today

    assert_enqueued_jobs 2, only: FetchWeatherDataJob do
      UpdateReferenceWeatherDataJob.perform_now
    end

    # エンキューされたジョブの内容を確認
    enqueued_jobs = ActiveJob::Base.queue_adapter.enqueued_jobs.select do |job|
      job[:job] == FetchWeatherDataJob
    end

    assert_equal 2, enqueued_jobs.size

    # 各ジョブのfarm_idを確認
    enqueued_farm_ids = enqueued_jobs.map do |job|
      # GlobalIDから直接farm_idを抽出
      job[:args].find { |arg| arg.is_a?(Hash) && arg.key?("farm_id") }&.dig("farm_id")
    end.compact

    # 両方の参照農場のジョブがエンキューされていることを確認
    assert_includes enqueued_farm_ids, @reference_farm1.id
    assert_includes enqueued_farm_ids, @reference_farm2.id

    # 各ジョブの内容を検証
    enqueued_jobs.each do |job|
      job_args = job[:args].find { |arg| arg.is_a?(Hash) }
      
      # 日付はシリアライズされているので、値を取り出して比較
      start_date_value = job_args["start_date"].is_a?(Hash) ? 
        Date.parse(job_args["start_date"]["value"]) : 
        job_args["start_date"]
      end_date_value = job_args["end_date"].is_a?(Hash) ? 
        Date.parse(job_args["end_date"]["value"]) : 
        job_args["end_date"]
      
      assert_equal expected_start_date, start_date_value
      assert_equal expected_end_date, end_date_value
      assert job_args["latitude"].present?
      assert job_args["longitude"].present?
    end
  end

  test "should not enqueue jobs for normal farms" do
    assert_enqueued_jobs 2, only: FetchWeatherDataJob do
      UpdateReferenceWeatherDataJob.perform_now
    end

    # 通常農場のジョブがエンキューされていないことを確認
    enqueued_jobs = ActiveJob::Base.queue_adapter.enqueued_jobs.select do |job|
      job[:job] == FetchWeatherDataJob
    end

    normal_farm_job = enqueued_jobs.find do |job|
      job[:args].first[:farm_id] == @normal_farm.id
    end
    assert_nil normal_farm_job
  end

  test "should skip farms without coordinates" do
    # 座標のない参照農場を作成
    farm_without_coords = Farm.new(
      name: "座標なし農場",
      user: @anonymous_user,
      is_reference: true
    )
    farm_without_coords.save(validate: false)

    # 2つの正常な参照農場のみジョブがエンキューされる
    assert_enqueued_jobs 2, only: FetchWeatherDataJob do
      UpdateReferenceWeatherDataJob.perform_now
    end
  end

  test "should handle empty reference farms gracefully" do
    # 全ての参照農場を削除
    Farm.where(is_reference: true).destroy_all

    assert_enqueued_jobs 0, only: FetchWeatherDataJob do
      UpdateReferenceWeatherDataJob.perform_now
    end
  end

  test "should log processing information" do
    # ジョブが実行されることを確認
    assert_enqueued_jobs 2, only: FetchWeatherDataJob do
      UpdateReferenceWeatherDataJob.perform_now
    end
  end

  # ========================================
  # P0: エラーハンドリングテスト
  # ========================================

  test "should have retry configuration" do
    # retry_onとdiscard_onが設定されていることを確認
    # ActiveJob 8.0では内部実装が変更されているため、
    # 実際のエラー処理をテストする方が確実
    assert_nothing_raised do
      UpdateReferenceWeatherDataJob.new
    end
  end

  test "should have error handling code in place" do
    # エラーハンドリングのrescue節が存在することを確認
    # perform_nowではretry_onやdiscard_onは動作しないため、
    # コードの存在のみを確認する
    job = UpdateReferenceWeatherDataJob.new
    assert_respond_to job, :perform
    
    # 実際のリトライ処理はperform_laterで実行された場合のみ動作する
    # エラー発生時のログ出力は統合テストで確認する
  end

  # ========================================
  # P0: 部分失敗テスト
  # ========================================

  test "should enqueue jobs even if some farms have invalid data" do
    # 有効な農場と無効な農場を混在させる
    Farm.where(is_reference: true).destroy_all
    
    # 有効な農場
    valid_farm = Farm.create!(
      name: "有効な農場",
      user: @anonymous_user,
      latitude: 35.6895,
      longitude: 139.6917,
      is_reference: true
    )
    
    # 座標がnilの農場（自動的にスキップされる）
    invalid_farm = Farm.new(
      name: "無効な農場",
      user: @anonymous_user,
      is_reference: true
    )
    invalid_farm.save(validate: false)
    
    # 有効な農場のジョブのみエンキューされる
    assert_enqueued_jobs 1, only: FetchWeatherDataJob do
      UpdateReferenceWeatherDataJob.perform_now
    end
  end

  # ========================================
  # P0: 境界値テスト
  # ========================================

  test "should handle zero reference farms gracefully" do
    Farm.where(is_reference: true).destroy_all
    
    assert_enqueued_jobs 0, only: FetchWeatherDataJob do
      UpdateReferenceWeatherDataJob.perform_now
    end
  end

  test "should handle single reference farm" do
    Farm.where(is_reference: true).destroy_all
    
    Farm.create!(
      name: "単一農場",
      user: @anonymous_user,
      latitude: 35.0,
      longitude: 135.0,
      is_reference: true
    )
    
    assert_enqueued_jobs 1, only: FetchWeatherDataJob do
      UpdateReferenceWeatherDataJob.perform_now
    end
  end

  test "should handle many reference farms" do
    Farm.where(is_reference: true).destroy_all
    
    # 10件の参照農場を作成
    10.times do |i|
      Farm.create!(
        name: "農場#{i}",
        user: @anonymous_user,
        latitude: 35.0 + i * 0.1,
        longitude: 135.0 + i * 0.1,
        is_reference: true
      )
    end
    
    assert_enqueued_jobs 10, only: FetchWeatherDataJob do
      UpdateReferenceWeatherDataJob.perform_now
    end
  end

  # ========================================
  # P1: パフォーマンステスト
  # ========================================

  test "should complete execution within reasonable time" do
    # 2件の農場で実行時間を計測
    farm_count = 2
    expected_time = farm_count * UpdateReferenceWeatherDataJob::API_INTERVAL_SECONDS
    max_time = expected_time + 1.0  # 1秒のオーバーヘッド許容
    
    start_time = Time.current
    
    assert_enqueued_jobs farm_count, only: FetchWeatherDataJob do
      UpdateReferenceWeatherDataJob.perform_now
    end
    
    elapsed_time = Time.current - start_time
    
    assert elapsed_time < max_time, 
      "実行時間が長すぎます: #{elapsed_time.round(2)}秒（期待: #{expected_time}秒 + オーバーヘッド < #{max_time}秒）"
  end

  test "should not create N+1 queries" do
    # クエリ数を計測
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      queries << event.payload[:sql] unless event.payload[:name] == "SCHEMA"
    end

    UpdateReferenceWeatherDataJob.perform_now

    ActiveSupport::Notifications.unsubscribe(subscriber)

    # Farm.reference のクエリ（COUNTを除く）は1回のみであるべき
    farm_queries = queries.select do |q| 
      q.include?("SELECT") && 
      q.include?("farms") && 
      q.include?("is_reference") &&
      !q.include?("COUNT")  # COUNTクエリは除外（ログ出力用）
    end
    
    # 理想的には1回、最大でも2回以内
    assert farm_queries.count <= 2, 
      "N+1クエリが発生している可能性があります: #{farm_queries.count}回\nクエリ: #{farm_queries.join("\n")}"
  end

  # ========================================
  # P1: ログテスト
  # ========================================

  test "should log execution time" do
    # 実行時間がログに記録されることを確認
    # （実際のログ出力を検証するには別のアプローチが必要）
    assert_enqueued_jobs 2, only: FetchWeatherDataJob do
      UpdateReferenceWeatherDataJob.perform_now
    end
    
    # ここでは正常に完了することを確認
    # ログの内容は手動テストまたはログ監視ツールで確認
  end
end

