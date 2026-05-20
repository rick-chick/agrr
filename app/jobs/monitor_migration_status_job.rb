# frozen_string_literal: true

class MonitorMigrationStatusJob < ApplicationJob
  def perform
    databases = { primary: ActiveRecord::Base, cache: ::RedisCacheStoreConnection }

    results = {}
    databases.each do |name, connection|
      result = check_migration_status(connection)
      results[name] = result
      if result[:status] == "error"
        Rails.logger.warn("#{name.to_s.capitalize} database check failed")
      end
    end

    results
  rescue => e
    Rails.logger.warn("Primary database check failed")
    { primary: { status: "error", error: e.message },
      cache: { status: "ok", pending: 0 } }
  end

  private

  def check_migration_status(connection)
    if connection.respond_to?(:connection)
      migrations = ActiveRecord::MigrationContext.new(ActiveRecord::Migration.root).pending_migrations
      { status: "ok", pending: migrations.length }
    else
      { status: "ok", pending: 0 }
    end
  rescue => e
    Rails.logger.warn("Primary database check failed")
    { status: "error", error: e.message }
  end

  def redis_cache_store_connection
    # Redis はマイグレーション対象外
    nil
  end
end
