# frozen_string_literal: true

require "test_helper"

class NavbarResearchLinkLocaleTest < ActionDispatch::IntegrationTest
  # Uses public layout which includes the navbar (auth layout does not)

  test "navbar research link points to /research/en/ when locale is us" do
    get "/us/public_plans"

    assert_response :success
    assert_select "a[href='/research/en/']", minimum: 1
  end

  test "navbar research link points to /research/ when locale is ja" do
    get "/ja/public_plans"

    assert_response :success
    assert_select "a[href='/research/']", minimum: 1
  end

  test "navbar research link points to /research/ when locale is in" do
    get "/in/public_plans"

    assert_response :success
    assert_select "a[href='/research/']", minimum: 1
  end

  test "default locale (no prefix) shows research link for /research/" do
    get "/public_plans"

    assert_response :success
    assert_select "a[href='/research/']", minimum: 1
  end
end
