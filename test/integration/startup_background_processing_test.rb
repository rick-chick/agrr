# frozen_string_literal: true

require "test_helper"

# 起動時のバックグラウンド処理の統合テスト
# 注意: このテストは実際の起動スクリプトを実行するのではなく、
# バックグラウンド処理で実行される主要な機能をテストします
class StartupBackgroundProcessingTest < ActionDispatch::IntegrationTest
  test "background database restoration can be performed" do
    # バックグラウンド処理で実行されるデータベース復元のロジックをテスト
    # 実際のLitestreamコマンドは実行しないが、データベース接続の準備を確認
    
    # キューデータベースの接続確認
    assert_nothing_raised do
      ActiveRecord::Base.connected_to(role: :writing, shard: :queue) do
        ActiveRecord::Base.connection.execute("SELECT 1")
      end
    end
    
    # キャッシュデータベースの接続確認
    assert_nothing_raised do
      ActiveRecord::Base.connected_to(role: :writing, shard: :cache) do
        ActiveRecord::Base.connection.execute("SELECT 1")
      end
    end
  end

  test "background migration can be performed" do
    # バックグラウンド処理で実行されるマイグレーションのロジックをテスト
    
    # キューデータベースのマイグレーション状態確認
    assert_nothing_raised do
      ActiveRecord::Base.connected_to(role: :writing, shard: :queue) do
        connection = ActiveRecord::Base.connection
        pending = connection.migration_context.pending_migrations
        assert pending.is_a?(Array)
      end
    end
    
    # キャッシュデータベースのマイグレーション状態確認
    assert_nothing_raised do
      ActiveRecord::Base.connected_to(role: :writing, shard: :cache) do
        connection = ActiveRecord::Base.connection
        pending = connection.migration_context.pending_migrations
        assert pending.is_a?(Array)
      end
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

