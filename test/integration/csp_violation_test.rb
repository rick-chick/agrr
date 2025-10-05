# frozen_string_literal: true

require "test_helper"

class CspViolationTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_authenticated_user
  end

  test "fields new page should not have CSP violations" do
    get new_field_path
    assert_response :success
    
    # Check that no inline styles are present (should be in external CSS)
    assert_no_match /<style[^>]*>/, response.body, "Inline styles detected - CSP violation"
    
    # Check that no inline scripts are present (should be in external JS)
    # This regex looks for script tags without src attribute
    assert_no_match /<script(?![^>]*src=)[^>]*>[^<]*</, response.body, "Inline scripts detected - CSP violation"
    
    # Check that external CSS and JS are properly linked
    assert_match /fields.*\.css/, response.body, "Fields CSS not properly linked"
    assert_match /fields.*\.js/, response.body, "Fields JS not properly linked"
    
    # Check that Leaflet files are loaded locally
    assert_match /href="\/leaflet\.css"/, response.body, "Leaflet CSS not loaded locally"
    assert_match /src="\/leaflet\.js"/, response.body, "Leaflet JS not loaded locally"
    
    # Verify no external CDN resources
    assert_no_match /https:\/\/unpkg\.com/, response.body, "External CDN resources detected"
  end

  test "fields edit page should not have CSP violations" do
    field = Field.create!(
      user: @user,
      name: "CSP Test Field",
      latitude: 35.6812,
      longitude: 139.7671
    )
    
    get edit_field_path(field)
    assert_response :success
    
    # Check that no inline styles are present
    assert_no_match /<style[^>]*>/, response.body, "Inline styles detected - CSP violation"
    
    # Check that no inline scripts are present
    # This regex looks for script tags without src attribute
    assert_no_match /<script(?![^>]*src=)[^>]*>[^<]*</, response.body, "Inline scripts detected - CSP violation"
    
    # Check that external CSS and JS are properly linked
    assert_match /fields.*\.css/, response.body, "Fields CSS not properly linked"
    assert_match /fields.*\.js/, response.body, "Fields JS not properly linked"
    
    # Check that Leaflet files are loaded locally
    assert_match /href="\/leaflet\.css"/, response.body, "Leaflet CSS not loaded locally"
    assert_match /src="\/leaflet\.js"/, response.body, "Leaflet JS not loaded locally"
  end

  test "fields index page should not have CSP violations" do
    get fields_path
    assert_response :success
    
    # Check that no inline styles are present
    assert_no_match /<style[^>]*>/, response.body, "Inline styles detected - CSP violation"
    
    # Check that no inline scripts are present
    # This regex looks for script tags without src attribute
    assert_no_match /<script(?![^>]*src=)[^>]*>[^<]*</, response.body, "Inline scripts detected - CSP violation"
    
    # Check that external CSS is properly linked
    assert_match /fields.*\.css/, response.body, "Fields CSS not properly linked"
  end

  test "fields show page should not have CSP violations" do
    field = Field.create!(
      user: @user,
      name: "CSP Test Field",
      latitude: 35.6812,
      longitude: 139.7671
    )
    
    get field_path(field)
    assert_response :success
    
    # Check that no inline styles are present
    assert_no_match /<style[^>]*>/, response.body, "Inline styles detected - CSP violation"
    
    # Check that no inline scripts are present
    # This regex looks for script tags without src attribute
    assert_no_match /<script(?![^>]*src=)[^>]*>[^<]*</, response.body, "Inline scripts detected - CSP violation"
    
    # Check that external CSS is properly linked
    assert_match /fields.*\.css/, response.body, "Fields CSS not properly linked"
  end

  test "all field pages should have proper CSP meta tag" do
    # Test new page
    get new_field_path
    assert_match /csp-nonce/, response.body, "CSP meta tag missing on new page"
    
    # Test index page
    get fields_path
    assert_match /csp-nonce/, response.body, "CSP meta tag missing on index page"
    
    # Test show page
    field = Field.create!(
      user: @user,
      name: "CSP Test Field",
      latitude: 35.6812,
      longitude: 139.7671
    )
    get field_path(field)
    assert_match /csp-nonce/, response.body, "CSP meta tag missing on show page"
    
    # Test edit page
    get edit_field_path(field)
    assert_match /csp-nonce/, response.body, "CSP meta tag missing on edit page"
  end

  test "field pages should load without external resource errors" do
    # Test that pages load successfully without external resource dependencies
    get new_field_path
    assert_response :success
    assert_no_match /net::ERR_NAME_NOT_RESOLVED/, response.body, "External resource resolution error detected"
    
    get fields_path
    assert_response :success
    assert_no_match /net::ERR_NAME_NOT_RESOLVED/, response.body, "External resource resolution error detected"
  end

  test "field forms should have proper form attributes" do
    get new_field_path
    assert_response :success
    
    # Check that form has proper attributes
    assert_match /<form[^>]*action="[^"]*fields"[^>]*method="post"/, response.body, "Form attributes not properly set"
    
    # Check that form fields have proper attributes
    assert_match /name="field\[name\]"/, response.body, "Name field not properly configured"
    assert_match /name="field\[latitude\]"/, response.body, "Latitude field not properly configured"
    assert_match /name="field\[longitude\]"/, response.body, "Longitude field not properly configured"
  end

  test "map container should be present without inline styles" do
    get new_field_path
    assert_response :success
    
    # Check that map container exists
    assert_match /id="map"/, response.body, "Map container not found"
    assert_match /class="map-container"/, response.body, "Map container class not found"
    
    # Check that no inline styles are applied to map
    assert_no_match /<div[^>]*id="map"[^>]*style=/, response.body, "Map container has inline styles"
  end

  test "coordinates input should have proper structure" do
    get new_field_path
    assert_response :success
    
    # Check that coordinates input container exists
    assert_match /class="coordinates-input"/, response.body, "Coordinates input container not found"
    
    # Check that both latitude and longitude inputs exist
    assert_match /name="field\[latitude\]"/, response.body, "Latitude input not found"
    assert_match /name="field\[longitude\]"/, response.body, "Longitude input not found"
    
    # Check that inputs have proper classes
    assert_match /class="[^"]*form-control[^"]*"[^>]*name="field\[latitude\]"/, response.body, "Latitude input missing form-control class"
    assert_match /class="[^"]*form-control[^"]*"[^>]*name="field\[longitude\]"/, response.body, "Longitude input missing form-control class"
  end
end
