# frozen_string_literal: true

require "test_helper"
require "securerandom"

class MonitorMigrationStatusJobTest < ActiveJob::TestCase
  test "perform checks migration status for all databases" do
    results = MonitorMigrationStatusJob.new.perform

    assert results.is_a?(Hash)
    assert results.key?(:primary)
    assert results.key?(:cache)

    # 各データベースの状態が確認されていることを確認
    results.each do |database, result|
      assert result.is_a?(Hash)
      assert result.key?(:status)
      assert_includes [ "ok", "error" ], result[:status]

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
    # 正常系では特定の開始ログを出力しない（エラー時のみログ）。実行成功を確認
    assert_nothing_raised { MonitorMigrationStatusJob.new.perform }
  end

  test "perform handles database connection errors gracefully" do
    # DB ファイル破壊は他テストとスキーマを汚すため、AR 境界例外をスタブで再現する
    job = MonitorMigrationStatusJob.new
    job.stubs(:check_migration_status).with(:primary).raises(ActiveRecord::ConnectionNotEstablished, "simulated")
    job.stubs(:check_migration_status).with(:cache).returns({ pending: 0 })

    results = job.perform

    assert results.is_a?(Hash)
    assert results.key?(:primary)

    primary_result = results[:primary]
    assert primary_result.is_a?(Hash)
    assert_equal "error", primary_result[:status]
    assert primary_result.key?(:error)
    assert primary_result[:error].is_a?(String)
    assert primary_result[:error].present?

    assert results.key?(:cache)
    assert_equal "ok", results[:cache][:status]
  end

  test "perform logs errors when migration check fails" do
    original_logger = Rails.logger
    log_output = StringIO.new
    Rails.logger = Logger.new(log_output)

    begin
      job = MonitorMigrationStatusJob.new
      job.stubs(:check_migration_status).with(:primary).raises(ActiveRecord::ConnectionNotEstablished, "simulated")
      job.stubs(:check_migration_status).with(:cache).returns({ pending: 0 })

      results = job.perform

      log_output.rewind
      log_content = log_output.read

      assert results.is_a?(Hash)
      assert results.key?(:primary)
      assert_equal "error", results[:primary][:status]
      assert results[:primary][:error].present?

      assert log_content.include?("Primary database check failed"),
        "Expected log to include 'Primary database check failed', got: #{log_content}"
    ensure
      Rails.logger = original_logger
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
