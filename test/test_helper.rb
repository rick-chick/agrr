ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

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
        avatar_url: 'https://example.com/avatar.jpg'
      )
      session = Session.create_for_user(user)
      cookies[:session_id] = session.session_id
      user
    end
  end
end



