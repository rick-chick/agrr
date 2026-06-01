# Test Helper for AGRR — R4 contract harness only (P8.5).
# API/WS の正: scripts/run-rust-contract-tests.sh
#
# 開発DBを壊さないため: RAILS_ENV=development 等でテスト実行された場合は即終了する
if ENV["RAILS_ENV"] && ENV["RAILS_ENV"] != "test"
  $stderr.puts <<~MSG.strip
    🚨🚨🚨 AGRR データベース保護ガード 🚨🚨🚨

    危険！ RAILS_ENV=#{ENV['RAILS_ENV'].inspect} でテストを実行しようとしています！
    これにより開発DB（#{ENV['DATABASE_URL'] || 'development.sqlite3'}）が壊れます！

    ✅ 正しい実行方法:
       .cursor/skills/test-common/scripts/run-test-rails.sh
       docker compose --profile test run --rm test bundle exec rails test

    🔄 前回DBが壊れた場合の復旧方法:
       docker compose down
       docker volume rm agrr_storage_dev_data
       .cursor/skills/dev-docker/scripts/up.sh
       # スキーマは test entrypoint が agrr-migrate schema run で適用（refinery）
  MSG
  exit 1
end
ENV["RAILS_ENV"] ||= "test"
if ENV.fetch("COVERAGE", "true") != "false"
  require "simplecov"
  SimpleCov.start "rails" do
    add_filter "/test/"
    add_filter "/config/"
    add_filter "/vendor/"
    add_filter "/tmp/"

    add_group "Models", "app/models"

    minimum_coverage 10
  end
end

require_relative "../config/environment"
require "rails/test_help"

# Load test support files
Dir[Rails.root.join("test", "support", "**", "*.rb")].each { |f| require f }

module ActiveSupport
  class TestCase
    # Include FactoryBot syntax methods
    include FactoryBot::Syntax::Methods

    # Run tests in parallel with specified workers
    # 並列テストはPARALLEL_TESTS環境変数で制御
    # デフォルトでは無効（SimpleCovのため）
    # 有効化: PARALLEL_TESTS=1 rails test
    # parallelize(workers: :number_of_processors) — PARALLEL_TESTS=1 で有効

    # テストデータは FactoryBot 等で都度作成（Minitest fixtures は未使用）

    setup do
      User.instance_variable_set(:@anonymous_user, nil)
      User.anonymous_user
      I18n.locale = :ja
    end
  end
end
