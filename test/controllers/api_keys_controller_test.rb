# frozen_string_literal: true

require "test_helper"

class ApiKeysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    sign_in_as @user
  end

  test "should show api key page" do
    get api_keys_path
    
    assert_response :success
    assert_select "h1", "APIキー管理"
  end

  test "should show generate button when api key is not set" do
    assert_not @user.has_api_key?
    
    get api_keys_path
    
    assert_response :success
    assert_select "button", "APIキーを生成"
  end

  test "should generate api key" do
    assert_not @user.has_api_key?
    
    post generate_api_key_path
    
    assert_redirected_to api_keys_path
    assert_equal "APIキーを生成しました。", flash[:notice]
    
    @user.reload
    assert @user.has_api_key?
    assert_not_nil @user.api_key
  end

  test "should show api key when it exists" do
    @user.generate_api_key!
    
    get api_keys_path
    
    assert_response :success
    assert_select "input#api_key[value=?]", @user.api_key
    assert_select "button", "APIキーを再生成"
  end

  test "should regenerate api key" do
    old_key = @user.generate_api_key!
    
    post regenerate_api_key_path
    
    assert_redirected_to api_keys_path
    assert_equal "APIキーを再生成しました。", flash[:notice]
    
    @user.reload
    assert_not_equal old_key, @user.api_key
  end

  test "should require authentication" do
    delete auth_logout_path
    
    get api_keys_path
    assert_redirected_to auth_login_path
  end
end
