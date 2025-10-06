# frozen_string_literal: true

require "test_helper"

class Asset404ErrorsTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_authenticated_user
  end

  test "should return 200 for leaflet.css via assets pipeline" do
    get "/assets/leaflet.css"
    assert_response :success
    assert_equal 'text/css', response.media_type
  end

  test "should return 200 for leaflet.js via assets pipeline" do
    get "/assets/leaflet.js"
    assert_response :success
    assert_equal 'text/javascript', response.media_type
  end

  test "should return 200 for dev-avatar.svg via assets pipeline" do
    get "/assets/dev-avatar.svg"
    assert_response :success
    assert_equal 'image/svg+xml', response.media_type
  end

  test "farm new page should reference leaflet files" do
    get new_farm_path
    assert_response :success
    
    # Check that the page references leaflet files via Rails helpers
    assert_select "link[href*='leaflet']"
    assert_select "script[src*='leaflet']"
  end

  test "farm edit page should reference leaflet files" do
    farm = Farm.create!(
      user: @user,
      name: "テスト農場",
      latitude: 35.6812,
      longitude: 139.7671
    )
    
    get edit_farm_path(farm)
    assert_response :success
    
    # Check that the page references leaflet files via Rails helpers
    assert_select "link[href*='leaflet']"
    assert_select "script[src*='leaflet']"
  end

  test "user avatar should reference dev-avatar.svg" do
    # Create a user with dev-avatar.svg reference
    user_with_avatar = User.create!(
      email: 'avatar@example.com',
      name: 'Avatar User',
      google_id: "google_#{SecureRandom.hex(8)}",
      avatar_url: '/assets/dev-avatar.svg'
    )
    
    session = Session.create_for_user(user_with_avatar)
    cookies[:session_id] = session.session_id
    
    get farms_path
    assert_response :success
    
    # Check that the page references the avatar file
    assert_select "img[src='/assets/dev-avatar.svg']"
  end

  test "fields.js should load with leaflet placeholder" do
    # This test verifies that fields.js loads with the leaflet placeholder
    get new_farm_path
    assert_response :success
    
    # The page should load and leaflet placeholder should be available
    assert_select "script[src*='fields']"
    assert_select "script[src='/leaflet.js']"
  end

  test "should handle assets gracefully in development" do
    # Test that the application loads properly with assets
    get new_farm_path
    assert_response :success
    
    # Page should render with assets
    assert_select "h1", "新しい農場を追加"
    assert_select "form"
  end

  test "should handle assets gracefully in edit form" do
    farm = Farm.create!(
      user: @user,
      name: "テスト農場",
      latitude: 35.6812,
      longitude: 139.7671
    )
    
    get edit_farm_path(farm)
    assert_response :success
    
    # Page should render with assets
    assert_select "h1", "農場を編集"
    assert_select "form"
  end

  test "should show 404 page for non-existent static assets" do
    # Test various non-existent static assets
    get "/non-existent.css"
    assert_response :not_found
    
    get "/non-existent.js"
    assert_response :not_found
    
    get "/assets/non-existent.png"
    assert_response :not_found
  end

  test "should handle leaflet files in map container" do
    get new_farm_path
    assert_response :success
    
    # Map container should exist and leaflet should be available
    assert_select "#map"
    assert_select ".map-container"
    
    # These selectors should be present and the resources should exist
    assert_select "link[href*='leaflet']"
    assert_select "script[src*='leaflet']"
  end
end
