# frozen_string_literal: true

require "test_helper"
require "securerandom"

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
        assert result.key?(:pending), "Expected 'pending' key in result for #{database}"
        assert result[:pending].is_a?(Integer), "Expected 'pending' to be an Integer for #{database}, got #{result[:pending].class}"
        assert result[:pending] >= 0, "Expected 'pending' to be >= 0 for #{database}, got #{result[:pending]}"
      else
        assert result.key?(:error), "Expected 'error' key in result for #{database}"
        assert result[:error].is_a?(String), "Expected 'error' to be a String for #{database}, got #{result[:error].class}"
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
    # パッチを使わずに、実際のエラーケースを再現するため、
    # データベースファイルを削除して接続を切断し、エラーを発生させる
    original_db_path = Rails.configuration.database_configuration[Rails.env]["primary"]["database"]
    db_path = Rails.root.join(original_db_path)
    backup_path = "#{db_path}.backup"
    
    begin
      # データベースファイルをバックアップして削除
      if File.exist?(db_path)
        FileUtils.cp(db_path, backup_path)
        FileUtils.rm(db_path)
      end
      
      # 接続プールを切断
      ActiveRecord::Base.connection_pool.disconnect!
      
      results = MonitorMigrationStatusJob.new.perform
      
      # 結果が正常に返されることを確認（エラーが発生しても、結果は返される）
      assert results.is_a?(Hash)
      assert results.key?(:primary)
      
      # エラーハンドリングが正しく動作することを確認
      primary_result = results[:primary]
      assert primary_result.is_a?(Hash)
      assert_equal "error", primary_result[:status]
      assert primary_result.key?(:error)
      assert primary_result[:error].is_a?(String)
      assert primary_result[:error].present?
    ensure
      # データベースファイルを復元
      if File.exist?(backup_path)
        FileUtils.cp(backup_path, db_path)
        FileUtils.rm(backup_path)
      end
      # 接続を再確立
      ActiveRecord::Base.establish_connection
    end
  end

  test "perform logs errors when migration check fails" do
    # マイグレーション状態確認が失敗した場合のログを確認
    original_logger = Rails.logger
    log_output = StringIO.new
    Rails.logger = Logger.new(log_output)
    
    original_db_path = Rails.configuration.database_configuration[Rails.env]["primary"]["database"]
    db_path = Rails.root.join(original_db_path)
    backup_path = "#{db_path}.backup"
    
    begin
      # データベースファイルをバックアップして削除
      if File.exist?(db_path)
        FileUtils.cp(db_path, backup_path)
        FileUtils.rm(db_path)
      end
      
      # 接続プールを切断
      ActiveRecord::Base.connection_pool.disconnect!
      
      results = MonitorMigrationStatusJob.new.perform
      
      log_output.rewind
      log_content = log_output.read
      
      # エラーハンドリングが正しく動作することを確認
      assert results.is_a?(Hash)
      assert results.key?(:primary)
      assert_equal "error", results[:primary][:status]
      assert results[:primary][:error].present?
      
      # エラーがログに記録されることを確認
      assert log_content.include?("Primary database check failed"), 
        "Expected log to include 'Primary database check failed', got: #{log_content}"
    ensure
      Rails.logger = original_logger
      # データベースファイルを復元
      if File.exist?(backup_path)
        FileUtils.cp(backup_path, db_path)
        FileUtils.rm(backup_path)
      end
      # 接続を再確立
      ActiveRecord::Base.establish_connection
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

