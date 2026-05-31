# frozen_string_literal: true

require "test_helper"

class AdaptersAuthSpaAuthRedirectTest < ActiveSupport::TestCase
  setup do
    @previous_frontend_url = ENV["FRONTEND_URL"]
    @previous_allowed_hosts = ENV["ALLOWED_HOSTS"]
    ENV["FRONTEND_URL"] = "http://127.0.0.1:4200,http://localhost:4200"
    ENV.delete("ALLOWED_HOSTS")
  end

  teardown do
    if @previous_frontend_url
      ENV["FRONTEND_URL"] = @previous_frontend_url
    else
      ENV.delete("FRONTEND_URL")
    end
    if @previous_allowed_hosts
      ENV["ALLOWED_HOSTS"] = @previous_allowed_hosts
    else
      ENV.delete("ALLOWED_HOSTS")
    end
  end

  test "login_url without return_to uses first FRONTEND_URL origin" do
    assert_equal "http://127.0.0.1:4200/login", Adapters::Auth::SpaAuthRedirect.login_url
  end

  test "login_url appends return_to when allowed" do
    url = Adapters::Auth::SpaAuthRedirect.login_url(return_to: "http://127.0.0.1:4200/plans")
    assert_equal "http://127.0.0.1:4200/login?return_to=http%3A%2F%2F127.0.0.1%3A4200%2Fplans", url
  end

  test "login_url omits disallowed return_to" do
    url = Adapters::Auth::SpaAuthRedirect.login_url(return_to: "https://evil.example/")
    assert_equal "http://127.0.0.1:4200/login", url
  end

  test "allowed_return_to accepts ALLOWED_HOSTS pattern" do
    ENV["ALLOWED_HOSTS"] = "agrr.net"
    assert Adapters::Auth::SpaAuthRedirect.allowed_return_to?("https://agrr.net/dashboard")
    assert_not Adapters::Auth::SpaAuthRedirect.allowed_return_to?("https://evil.example/")
  end

  test "allowed_return_to accepts request origin when provided" do
    assert Adapters::Auth::SpaAuthRedirect.allowed_return_to?(
      "http://localhost:3000/foo",
      request_base_url: "http://localhost:3000"
    )
  end
end
