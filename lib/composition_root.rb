# frozen_string_literal: true

# Composition Root (Rails shell): dev/test auth mock and session cookie resolution only.
# API / jobs / domain use cases run on agrr-server (Rust).
module CompositionRoot
  class << self
    def reset!
      instance_variables.each { |iv| remove_instance_variable(iv) }
    end

    def oauth_conversion_url_appender
      @oauth_conversion_url_appender ||= Adapters::Application::OauthConversionUrlAppender.new
    end

    def user_session_revocation_gateway
      @user_session_revocation_gateway ||= Adapters::Shared::Gateways::UserSessionRevocationActiveRecordGateway.new
    end

    def auth_test_login_gateway
      @auth_test_login_gateway ||= Adapters::Shared::Gateways::AuthTestLoginActiveRecordGateway.new
    end

    def session_cookie_user_gateway
      @session_cookie_user_gateway ||= Adapters::Shared::Gateways::SessionCookieUserActiveRecordGateway.new
    end
  end
end
