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
      User.instance_variable_set(:@anonymous_user, nil)
      User.anonymous_user
      # Set default locale for URL helpers
      I18n.locale = :ja
      # Set default URL options for route helpers
      Rails.application.routes.default_url_options[:locale] = :ja
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



