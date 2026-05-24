# frozen_string_literal: true

require "test_helper"

class NavbarResearchLinkLocaleTest < ActionDispatch::IntegrationTest
  # Uses public layout which includes the navbar (auth layout does not)

  test "navbar research link points to /research/en/ when locale is us" do
    get "/us/about"

    assert_response :success
    assert_select "a[href='/research/en/']", minimum: 1
  end

  test "navbar research link points to /research/ when locale is ja" do
    get "/ja/about"

    assert_response :success
    assert_select "a[href='/research/']", minimum: 1
  end

  test "navbar research link points to /research/ when locale is in" do
    get "/in/about"

    assert_response :success
    assert_select "a[href='/research/']", minimum: 1
  end

  test "default locale (no prefix) shows research link for /research/" do
    get "/about"

    assert_response :success
    assert_select "a[href='/research/']", minimum: 1
  end
end
