# frozen_string_literal: true

require 'test_helper'

class SitemapsControllerTest < ActionDispatch::IntegrationTest
  test "should get sitemap.xml" do
    get '/sitemap.xml'
    assert_response :success
    assert_equal 'application/xml; charset=utf-8', response.content_type
  end

  test "sitemap should contain all important pages" do
    get '/sitemap.xml'
    assert_response :success
    
    # Check for all important URLs
    assert_match %r{<loc>.*?/</loc>}, response.body # Home
    assert_match %r{<loc>.*?/public_plans</loc>}, response.body
    assert_match %r{<loc>.*?/about</loc>}, response.body
    assert_match %r{<loc>.*?/contact</loc>}, response.body
    assert_match %r{<loc>.*?/privacy</loc>}, response.body
    assert_match %r{<loc>.*?/terms</loc>}, response.body
  end

  test "sitemap should have valid XML structure" do
    get '/sitemap.xml'
    assert_response :success
    
    assert_match %r{<\?xml version="1.0" encoding="UTF-8"\?>}, response.body
    assert_match %r{<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">}, response.body
  end
end

