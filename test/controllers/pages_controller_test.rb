# frozen_string_literal: true

require 'test_helper'

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get privacy page" do
    get privacy_path
    assert_response :success
    assert_select 'h1', 'プライバシーポリシー'
  end

  test "should get terms page" do
    get terms_path
    assert_response :success
    assert_select 'h1', '利用規約'
  end

  test "should get contact page" do
    get contact_path
    assert_response :success
    assert_select 'h1', 'お問い合わせ'
  end

  test "should get about page" do
    get about_path
    assert_response :success
    assert_select 'h1', 'AGRRについて'
  end

  test "privacy page should contain required information" do
    get privacy_path
    assert_response :success
    assert_select 'body', /収集する情報/
    assert_select 'body', /利用目的/
    assert_select 'body', /Google AdSense/
  end

  test "terms page should contain required sections" do
    get terms_path
    assert_response :success
    assert_select 'body', /適用/
    assert_select 'body', /禁止事項/
    assert_select 'body', /免責事項/
  end

  test "contact page should contain email address" do
    get contact_path
    assert_response :success
    assert_select 'a[href=?]', 'mailto:support@agrr.net'
  end

  test "about page should contain service description" do
    get about_path
    assert_response :success
    assert_select 'body', /作付け計画/
    assert_select 'body', /圃場管理/
  end

  test "all pages should be accessible without authentication" do
    # 認証なしで各ページにアクセスできることを確認
    [privacy_path, terms_path, contact_path, about_path].each do |path|
      get path
      assert_response :success
    end
  end
end

