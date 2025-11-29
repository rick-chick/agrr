# frozen_string_literal: true

# マイグレーション状態を監視するジョブ
# バックグラウンドで実行されるマイグレーションの状態を確認し、エラーがあればログに記録
class MonitorMigrationStatusJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "[MonitorMigrationStatusJob] Checking migration status..."
    
    results = {}
    
    # メインデータベースのマイグレーション状態確認
    begin
      primary_status = check_migration_status(:primary)
      results[:primary] = { status: 'ok', pending: primary_status[:pending] }
      Rails.logger.info "[MonitorMigrationStatusJob] Primary database: #{primary_status[:pending]} pending migrations"
    rescue => e
      results[:primary] = { status: 'error', error: e.message }
      Rails.logger.error "[MonitorMigrationStatusJob] Primary database check failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
    
    # キューデータベースのマイグレーション状態確認
    begin
      queue_status = check_migration_status(:queue)
      results[:queue] = { status: 'ok', pending: queue_status[:pending] }
      Rails.logger.info "[MonitorMigrationStatusJob] Queue database: #{queue_status[:pending]} pending migrations"
    rescue => e
      results[:queue] = { status: 'error', error: e.message }
      Rails.logger.error "[MonitorMigrationStatusJob] Queue database check failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
    
    # キャッシュデータベースのマイグレーション状態確認
    begin
      cache_status = check_migration_status(:cache)
      results[:cache] = { status: 'ok', pending: cache_status[:pending] }
      Rails.logger.info "[MonitorMigrationStatusJob] Cache database: #{cache_status[:pending]} pending migrations"
    rescue => e
      results[:cache] = { status: 'error', error: e.message }
      Rails.logger.error "[MonitorMigrationStatusJob] Cache database check failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
    
    # エラーがある場合は警告ログを出力
    errors = results.select { |_db, result| result[:status] == 'error' }
    if errors.any?
      Rails.logger.warn "[MonitorMigrationStatusJob] Migration check found errors: #{errors.keys.join(', ')}"
    end
    
    results
  end

  private

  def check_migration_status(database)
    # データベース接続を取得してマイグレーション状態を確認
    case database
    when :primary
      # メインデータベースの接続を使用
      connection = ActiveRecord::Base.connection
      pending = connection.migration_context.pending_migrations
      { pending: pending.size }
    when :queue
      # キューデータベースの接続を取得
      # Rails 8の複数データベース対応を使用
      ActiveRecord::Base.connected_to(role: :writing, shard: :queue) do
        connection = ActiveRecord::Base.connection
        pending = connection.migration_context.pending_migrations
        { pending: pending.size }
      end
    when :cache
      # キャッシュデータベースの接続を取得
      ActiveRecord::Base.connected_to(role: :writing, shard: :cache) do
        connection = ActiveRecord::Base.connection
        pending = connection.migration_context.pending_migrations
        { pending: pending.size }
      end
    else
      { pending: 0, error: "Unknown database: #{database}" }
    end
  rescue => e
    { pending: -1, error: e.message }
  end
end

