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

    💡 このガードをバイパスするには ALLOW_DIRECT_RAILS_TEST=1 を設定
       （ただしDBが壊れるリスクを理解した上で使用してください）

    🔄 前回DBが壊れた場合の復旧方法:
       docker compose down
       docker volume rm agrr_storage_dev_data
       git checkout db/schema.rb
       docker compose up -d web
  MSG
  exit 1
end
ENV["RAILS_ENV"] ||= "test"
if ENV.fetch("COVERAGE", "true") != "false"
  require 'simplecov'
  SimpleCov.start 'rails' do
    add_filter '/test/'
    add_filter '/config/'
    add_filter '/vendor/'
    add_filter '/tmp/'
    
    add_group 'Controllers', 'app/controllers'
    add_group 'Models', 'app/models'
    add_group 'Views', 'app/views'
    add_group 'Helpers', 'app/helpers'
    add_group 'Jobs', 'app/jobs'
    add_group 'Mailers', 'app/mailers'
    
    minimum_coverage 10
  end
end

require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require 'mocha/minitest'

# Expose aliases for controllers tests to stub without loading the controller directly.
module Api
  module V1
    module Plans
      FieldCultivationClimateDataInteractor =
        Domain::FieldCultivation::Interactors::FieldCultivationClimateDataInteractor
    end

    module PublicPlans
      FieldCultivationClimateDataInteractor =
        Domain::FieldCultivation::Interactors::FieldCultivationClimateDataInteractor
    end
  end
end

# Load test support files
Dir[Rails.root.join('test', 'support', '**', '*.rb')].each { |f| require f }

module ActiveSupport
  class TestCase
    # Include AGRR mock helper
    include AgrrMockHelper
    
    # Include FactoryBot syntax methods
    include FactoryBot::Syntax::Methods
    
    # Run tests in parallel with specified workers
    # 並列テストはPARALLEL_TESTS環境変数で制御
    # デフォルトでは無効（SimpleCovのため）
    # 有効化: PARALLEL_TESTS=1 rails test
    # parallelize(workers: :number_of_processors) # parallel_test_config.rbで管理

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    # フィクスチャの外部キー制約違反を避けるため、コメントアウト
    # FactoryBotを使用してテストデータを作成
    # fixtures :all

    # テスト開始前にアノニマスユーザーを作成
    setup do
      # application.jsがビルドされているか確認し、なければダミーファイルを作成
      ensure_application_js_built
      
      User.instance_variable_set(:@anonymous_user, nil)
      User.anonymous_user
      # Set default locale for URL helpers
      I18n.locale = :ja
      # Set default URL options for route helpers
      Rails.application.routes.default_url_options[:locale] = :ja
    end
    
    # application.jsがビルドされているか確認し、なければダミーファイルを作成
    def ensure_application_js_built
      app_js_path = Rails.root.join('app', 'assets', 'builds', 'application.js')
      unless File.exist?(app_js_path)
        Rails.logger.warn "[Test] ⚠️ application.js not found at #{app_js_path}"
        Rails.logger.warn "[Test] Creating dummy application.js for test environment (Propshaft requires this)"
        
        # Propshaftが存在しないアセットに対してエラーを発生させるため、ダミーファイルを作成
        FileUtils.mkdir_p(app_js_path.dirname)
        File.write(app_js_path, "// Dummy application.js for test environment\n// This file is auto-generated when application.js is not built\n")
        
        Rails.logger.info "[Test] ✓ Created dummy application.js"
      end
    end

    # URLヘルパーのデフォルトオプションを設定
    def default_url_options
      { locale: I18n.locale }
    end

    # Add more helper methods to be used by all tests here...
    
    # OAuth test helpers
    def setup_omniauth_mock(provider, auth_hash)
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[provider.to_sym] = auth_hash
    end

    def clear_omniauth_mock
      OmniAuth.config.test_mode = false
      OmniAuth.config.mock_auth.clear
    end

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
      { 'Cookie' => "session_id=#{session_id}" }
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



