# Test Helper for AGRR
#
# ⚠️ IMPORTANT: Testing guidelines must be followed
# See: docs/TESTING_GUIDELINES.md
#
# Key requirements:
# - Model-level tests for all validations (REQUIRED)
# - Integration tests for service objects (REQUIRED)
# - Resource limit testing (MANDATORY)
# - No patches - use dependency injection instead
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
require "mocha/minitest"

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
    # parallelize(workers: :number_of_processors) # parallel_test_config.rbで管理

    # テストデータは FactoryBot 等で都度作成（Minitest fixtures は未使用）

    setup do
      User.instance_variable_set(:@anonymous_user, nil)
      User.anonymous_user
      I18n.locale = :ja
      Rails.application.routes.default_url_options[:locale] = :ja
    end

    # URLヘルパーのデフォルトオプションを設定
    def default_url_options
      { locale: I18n.locale }
    end

    # Add more helper methods to be used by all tests here...

    def create_authenticated_user
      user = create(:user)
      session = create(:session, user: user)
      cookies[:session_id] = session.session_id
      user
    end

    def sign_in_as(user)
      session = create(:session, user: user)
      cookies[:session_id] = session.session_id
    end

    # IntegrationTest用のヘルパーメソッド
    def create_session_for(user)
      session = create(:session, user: user)
      session.session_id
    end

    def session_cookie_header(session_id)
      { "Cookie" => "session_id=#{session_id}" }
    end
  end
end

# Integration Test用のURL設定
module ActionDispatch
  class IntegrationTest
    def default_url_options
      { locale: I18n.locale }
    end
  end
end
