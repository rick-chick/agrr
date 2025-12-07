# frozen_string_literal: true

require "test_helper"

class ApplicationControllerLocaleTest < ActionController::TestCase
  tests ApplicationController

  test "hi Accept-Language maps to :in locale" do
    @request.env['HTTP_ACCEPT_LANGUAGE'] = "hi-IN,hi;q=0.9"

    assert_equal 'in', @controller.send(:extract_locale_from_accept_language_header)
  end
end

