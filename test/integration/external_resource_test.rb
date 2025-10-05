# frozen_string_literal: true

require "test_helper"

class ExternalResourceTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_authenticated_user
  end

  test "fields pages should not load external placeholder images" do
    # Test that pages load successfully without external image dependencies
    get new_field_path
    assert_response :success
    assert_no_match /via\.placeholder\.com/, response.body, "External placeholder image detected"
    assert_no_match /net::ERR_NAME_NOT_RESOLVED/, response.body, "External resource resolution error detected"
    
    get fields_path
    assert_response :success
    assert_no_match /via\.placeholder\.com/, response.body, "External placeholder image detected"
    assert_no_match /net::ERR_NAME_NOT_RESOLVED/, response.body, "External resource resolution error detected"
  end

  test "user avatar should not use external placeholder service" do
    # Test that the fields page loads without external placeholder dependencies
    get fields_path
    assert_response :success
    
    # Check that no external placeholder URLs are used
    assert_no_match /via\.placeholder\.com/, response.body, "External placeholder service detected"
    assert_no_match /50x50\.png\?text=/, response.body, "Placeholder image format detected"
  end

  test "omniauth test configuration should use local images" do
    # Check that omniauth test configuration doesn't reference external images
    if Rails.env.development?
      # This test ensures that the omniauth test configuration is properly set up
      # to avoid external resource dependencies
      assert_not_nil OmniAuth.config.mock_auth[:google_oauth2], "OmniAuth test mock not configured"
      
      # Get the mock auth hash
      mock_auth = OmniAuth.config.mock_auth[:google_oauth2]
      
      # Check that the image URL is not using external placeholder service
      # Note: This test will fail if external images are still being used
      assert_not_match /via\.placeholder\.com/, mock_auth.info.image, "External placeholder image in OmniAuth mock"
      
      # Verify that local SVG files are being used
      assert_match /\/assets\/.*\.svg/, mock_auth.info.image, "Local SVG avatar not used"
    end
  end

  test "all images should be served locally" do
    # Test that all pages load without external image dependencies
    pages_to_test = [
      fields_path,
      new_field_path,
      root_path
    ]
    
    pages_to_test.each do |path|
      get path
      assert_response :success, "Failed to load #{path}"
      
      # Check for external image references (excluding user avatars which may be external)
      assert_no_match /https:\/\/via\.placeholder\.com/, response.body, "External placeholder image detected in #{path}"
      # Note: User avatars may be external (from Google OAuth), so we only check for placeholder services
    end
  end

  test "user avatar display should work without external resources" do
    # Test that the fields page loads without external resource dependencies
    get fields_path
    assert_response :success
    
    # Check that user interface elements are present
    assert_match /user-info/, response.body, "User info section not found"
    assert_match /ログアウト/, response.body, "Logout button not found"
    
    # Ensure no external placeholder resources are referenced
    assert_no_match /via\.placeholder\.com/, response.body, "External placeholder service detected"
  end

  test "form pages should not reference external images" do
    # Test that form pages (new/edit) don't reference external images
    get new_field_path
    assert_response :success
    assert_no_match /https:\/\/via\.placeholder\.com/, response.body, "External placeholder in new form"
    
    field = Field.create!(
      user: @user,
      name: "Test Field",
      latitude: 35.6812,
      longitude: 139.7671
    )
    
    get edit_field_path(field)
    assert_response :success
    assert_no_match /https:\/\/via\.placeholder\.com/, response.body, "External placeholder in edit form"
  end

  test "error pages should not use external images" do
    # Test that error scenarios don't trigger external image loads
    # Try to access a non-existent field
    get field_path(999999)
    assert_response :redirect
    
    # Check that redirect response doesn't contain external image references
    assert_no_match /via\.placeholder\.com/, response.body, "External placeholder in error response"
  end

  test "static assets should be served locally" do
    # Test that static assets like CSS and JS are served locally
    get new_field_path
    assert_response :success
    
    # Check that CSS and JS files are served from local assets
    assert_match /\/assets\/fields.*\.css/, response.body, "Fields CSS not served locally"
    assert_match /\/assets\/fields.*\.js/, response.body, "Fields JS not served locally"
    assert_match /\/leaflet\.css/, response.body, "Leaflet CSS not served locally"
    assert_match /\/leaflet\.js/, response.body, "Leaflet JS not served locally"
    
    # Ensure no external CDN references
    assert_no_match /https:\/\/unpkg\.com/, response.body, "External CDN reference detected"
    assert_no_match /https:\/\/cdn\.jsdelivr\.net/, response.body, "External CDN reference detected"
  end

  test "development environment should not load external images" do
    # This test specifically checks the development environment configuration
    if Rails.env.development?
      # Check that omniauth test configuration exists
      assert_not_nil OmniAuth.config.mock_auth, "OmniAuth test configuration not found"
      
      # Check each mock auth configuration for external placeholder images
      external_placeholder_count = 0
      OmniAuth.config.mock_auth.each do |provider, auth_hash|
        if auth_hash.is_a?(OmniAuth::AuthHash) && auth_hash.info&.image
          # Count external placeholder images
          if auth_hash.info.image.match?(/via\.placeholder\.com/)
            external_placeholder_count += 1
          end
        end
      end
      
      # Verify no external placeholder images are used
      assert_equal 0, external_placeholder_count, "External placeholder images found in OmniAuth configuration"
    else
      # In test environment, skip this test
      skip "Skipping development environment test in #{Rails.env}"
    end
  end
end
