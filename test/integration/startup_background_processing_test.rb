# frozen_string_literal: true

require "test_helper"

# 起動時のバックグラウンド処理の統合テスト
# 注意: このテストは実際の起動スクリプトを実行するのではなく、
# バックグラウンド処理で実行される主要な機能をテストします
class StartupBackgroundProcessingTest < ActionDispatch::IntegrationTest
  test "background database restoration can be performed" do
    # バックグラウンド処理で実行されるデータベース復元のロジックをテスト
    # 実際のLitestreamコマンドは実行しないが、データベース接続の準備を確認
    
    # メインデータベースの接続確認
    assert_nothing_raised do
      ActiveRecord::Base.connection.execute("SELECT 1")
    end
    
    # キューデータベースとキャッシュデータベースの接続は、
    # MonitorMigrationStatusJobを通じて確認する（統合テスト）
    # 実際の接続設定は、MonitorMigrationStatusJobTestで確認される
    # このテストでは、MonitorMigrationStatusJobが正常に動作することを確認する
    results = MonitorMigrationStatusJob.perform_now
    assert results.is_a?(Hash)
    assert results.key?(:queue)
    assert results.key?(:cache)
  end

  test "background migration can be performed" do
    # バックグラウンド処理で実行されるマイグレーションのロジックをテスト
    # MonitorMigrationStatusJobを使ってマイグレーション状態を確認
    
    # MonitorMigrationStatusJobが正常に動作することを確認
    results = MonitorMigrationStatusJob.perform_now
    
    assert results.is_a?(Hash)
    assert results.key?(:primary)
    assert results.key?(:queue)
    assert results.key?(:cache)
    # 各データベースの状態が確認されていることを確認
    results.each do |_database, result|
      assert result.is_a?(Hash)
      assert result.key?(:status)
      assert_includes ["ok", "error"], result[:status]
    end
  end

  test "monitor migration status job can be enqueued" do
    # マイグレーション状態監視ジョブがエンキューできることを確認
    assert_enqueued_with(job: MonitorMigrationStatusJob) do
      MonitorMigrationStatusJob.perform_later
    end
  end

  test "monitor migration status job performs successfully" do
    # マイグレーション状態監視ジョブが正常に実行できることを確認
    perform_enqueued_jobs do
      results = MonitorMigrationStatusJob.perform_now
      
      assert results.is_a?(Hash)
      assert results.key?(:primary)
      assert results.key?(:queue)
      assert results.key?(:cache)
    end
  end
end

