# frozen_string_literal: true

require "test_helper"

class ApplicationControllerLocaleTest < ActionController::TestCase
  tests ApplicationController

  setup do
    @request.cookies.clear
    @request.env.delete('HTTP_ACCEPT_LANGUAGE')
    @request.path = '/'
  end

  test "hi Accept-Language maps to :in locale" do
    @request.env['HTTP_ACCEPT_LANGUAGE'] = "hi-IN,hi;q=0.9"

    assert_equal 'in', @controller.send(:extract_locale_from_accept_language_header)
  end

  test "path locale takes precedence over cookie and header" do
    @request.path = '/us/auth/login'
    @request.cookies['locale'] = 'in'
    @request.env['HTTP_ACCEPT_LANGUAGE'] = 'ja-JP,ja;q=0.9'

    assert_equal 'us', captured_locale_from_switch
  end

  test "cookie locale is used when path locale is absent" do
    @request.path = '/auth/login'
    @request.cookies['locale'] = 'in'
    @request.env['HTTP_ACCEPT_LANGUAGE'] = 'ja-JP,ja;q=0.9'

    assert_equal 'in', captured_locale_from_switch
  end

  test "Accept-Language header is used when path and cookie are absent" do
    @request.path = '/auth/login'
    @request.env['HTTP_ACCEPT_LANGUAGE'] = 'en-US,en;q=0.9'

    assert_equal 'us', captured_locale_from_switch
  end

  test "default locale is used when no hints exist" do
    @request.path = '/auth/login'

    assert_equal I18n.default_locale.to_s, captured_locale_from_switch
  end

  private

  def captured_locale_from_switch
    result = nil
    @controller.send(:switch_locale) do
      result = I18n.locale
    end
    result.to_s
  end
end

