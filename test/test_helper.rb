ENV["RAILS_ENV"] ||= "test"
require 'simplecov'
SimpleCov.start 'rails' do
  add_filter '/test/'
  add_filter '/config/'
  add_filter '/vendor/'
  add_filter '/tmp/'
  
  # Include weather-related files in coverage
  # (コメントアウト: すべてのファイルを対象にする)
  # add_filter do |source_file|
  #   !source_file.filename.include?('crop') && 
  #   !source_file.filename.include?('application') &&
  #   !source_file.filename.include?('auth')
  # end
  
  add_group 'Controllers', 'app/controllers'
  add_group 'Models', 'app/models'
  add_group 'Views', 'app/views'
  add_group 'Helpers', 'app/helpers'
  add_group 'Jobs', 'app/jobs'
  add_group 'Mailers', 'app/mailers'
  
  minimum_coverage 10
end

require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    # parallelize(workers: :number_of_processors) # Disabled for SimpleCov

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # テスト開始前にアノニマスユーザーを作成
    setup do
      User.instance_variable_set(:@anonymous_user, nil)
      User.anonymous_user
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
      user = User.create!(
        email: 'test@example.com',
        name: 'Test User',
        google_id: "google_#{SecureRandom.hex(8)}",
        avatar_url: 'dev-avatar.svg'
      )
      session = Session.create_for_user(user)
      cookies[:session_id] = session.session_id
      user
    end

    def sign_in_as(user)
      session = Session.create_for_user(user)
      cookies[:session_id] = session.session_id
    end
  end
end



