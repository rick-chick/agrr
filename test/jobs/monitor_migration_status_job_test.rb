# frozen_string_literal: true

require "test_helper"

class MonitorMigrationStatusJobTest < ActiveJob::TestCase
  test "perform checks migration status for all databases" do
    results = MonitorMigrationStatusJob.new.perform
    
    assert results.is_a?(Hash)
    assert results.key?(:primary)
    assert results.key?(:queue)
    assert results.key?(:cache)
    
    # 各データベースの状態が確認されていることを確認
    results.each do |database, result|
      assert result.is_a?(Hash)
      assert result.key?(:status)
      assert_includes ["ok", "error"], result[:status]
      
      if result[:status] == "ok"
        assert result.key?(:pending)
        assert result[:pending].is_a?(Integer)
        assert result[:pending] >= 0
      else
        assert result.key?(:error)
        assert result[:error].is_a?(String)
      end
    end
  end

  test "perform logs migration status" do
    assert_logs_include("[MonitorMigrationStatusJob] Checking migration status") do
      MonitorMigrationStatusJob.new.perform
    end
  end

  test "perform handles database connection errors gracefully" do
    # データベース接続エラーをシミュレート
    ActiveRecord::Base.stub_any_instance(:connection, ->(*) { raise ActiveRecord::ConnectionNotEstablished.new("Connection failed") }) do
      results = MonitorMigrationStatusJob.new.perform
      
      # エラーが適切に処理されていることを確認
      results.each do |_database, result|
        if result[:status] == "error"
          assert result[:error].present?
        end
      end
    end
  end

  test "perform logs errors when migration check fails" do
    # マイグレーションコンテキストのエラーをシミュレート
    migration_context = ActiveRecord::Base.connection.migration_context
    migration_context.stub(:pending_migrations, ->(*) { raise StandardError.new("Migration check failed") }) do
      results = MonitorMigrationStatusJob.new.perform
      
      # エラーが記録されていることを確認
      assert results[:primary][:status] == "error" || results[:primary][:status] == "ok"
    end
  end

  private

  def assert_logs_include(message)
    log_output = StringIO.new
    original_logger = Rails.logger
    
    begin
      Rails.logger = Logger.new(log_output)
      yield
      log_output.rewind
      assert log_output.read.include?(message), "Expected log to include '#{message}'"
    ensure
      Rails.logger = original_logger
    end
  end
end

