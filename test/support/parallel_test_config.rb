# frozen_string_literal: true

# 並列テスト実行の設定
# SimpleCovと並列テストを両立させる

if ENV['PARALLEL_TESTS']
  # 並列テスト実行時の設定
  class ActiveSupport::TestCase
    # 並列テストを有効化
    parallelize(workers: :number_of_processors)
    
    # 並列テストのセットアップ
    parallelize_setup do |worker|
      # SimpleCovのフォーマットを並列テスト用に調整
      if defined?(SimpleCov)
        SimpleCov.command_name "test:worker_#{worker}"
      end
      
      # データベースのセットアップ
      ActiveRecord::Base.connection.execute("PRAGMA journal_mode = WAL")
      ActiveRecord::Base.connection.execute("PRAGMA synchronous = NORMAL")
    end
    
    # 並列テストのクリーンアップ
    parallelize_teardown do |worker|
      # SimpleCovの結果を保存
      if defined?(SimpleCov)
        SimpleCov.result.format!
      end
    end
  end
else
  # 並列テストを無効化（SimpleCovのため）
  # デフォルトでは並列実行しない
end

