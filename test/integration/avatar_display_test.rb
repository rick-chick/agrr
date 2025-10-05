# frozen_string_literal: true

require "test_helper"

class AvatarDisplayTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_authenticated_user
  end

  test "avatar should display correctly on fields page" do
    get fields_path
    assert_response :success
    
    # Check that user avatar is displayed
    assert_select "img.user-avatar", count: 1
    assert_select "img[alt='User Avatar']", count: 1
  end

  test "avatar should display correctly on new field page" do
    get new_field_path
    assert_response :success
    
    # Check that user avatar is displayed
    assert_select "img.user-avatar", count: 1
  end

  test "avatar should display correctly on home page" do
    get root_path
    assert_response :success
    
    # Check that user avatar is displayed
    assert_select "img.user-avatar", count: 1
  end

  test "avatar should be accessible via direct URL" do
    get "/assets/dev-avatar.svg"
    assert_response :success
    assert_equal "image/svg+xml", response.content_type
    assert_match /<svg/, response.body
  end

  test "all avatar files should be accessible" do
    avatar_files = ['dev-avatar.svg', 'farm-avatar.svg', 'res-avatar.svg', 'default-avatar.svg']
    
    avatar_files.each do |avatar_file|
      get "/assets/#{avatar_file}"
      assert_response :success, "Avatar file #{avatar_file} should be accessible"
      assert_equal "image/svg+xml", response.content_type, "Avatar file #{avatar_file} should have correct content type"
      assert_match /<svg/, response.body, "Avatar file #{avatar_file} should contain SVG content"
    end
  end

  test "user with different avatar should display correctly" do
    # Update user to use farm avatar
    @user.update!(avatar_url: '/assets/farm-avatar.svg')
    
    get fields_path
    assert_response :success
    
    # Check that farm avatar is displayed
    assert_select "img.user-avatar", count: 1
    assert_select "img[src='/assets/farm-avatar.svg']", count: 1
  end

  test "user without avatar should not display avatar image" do
    # Update user to have no avatar
    @user.update!(avatar_url: nil)
    
    get fields_path
    assert_response :success
    
    # Check that no avatar is displayed
    assert_select "img.user-avatar", count: 0
  end

  test "avatar should have proper CSS classes" do
    get fields_path
    assert_response :success
    
    # Check that avatar has proper CSS class
    assert_select "img.user-avatar", count: 1
    
    # Check that the image is properly contained within user-info
    assert_select ".user-info img.user-avatar", count: 1
  end

  test "avatar should be responsive and properly sized" do
    get fields_path
    assert_response :success
    
    # Check that avatar image is present
    img_element = css_select("img.user-avatar").first
    assert_not_nil img_element, "Avatar image should be present"
    
    # Check that alt text is present
    assert_equal "User Avatar", img_element["alt"], "Avatar should have proper alt text"
  end

  test "avatar should not reference external URLs" do
    get fields_path
    assert_response :success
    
    # Check that no external avatar URLs are used
    assert_no_match /https:\/\/via\.placeholder\.com/, response.body, "External placeholder avatar detected"
    assert_no_match /https:\/\/example\.com/, response.body, "External example avatar detected"
    
    # Verify local avatar is used
    assert_match /\/assets\/.*\.svg/, response.body, "Local avatar should be used"
  end
end
