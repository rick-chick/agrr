# frozen_string_literal: true

require "test_helper"

class FarmsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_authenticated_user
    @farm = Farm.create!(
      user: @user,
      name: "テスト農場",
      latitude: 35.6812,
      longitude: 139.7671
    )
  end

  test "should get index when authenticated" do
    get farms_path
    assert_response :success
    assert_select "h1", "農場一覧"
  end

  test "should redirect to login when not authenticated" do
    delete auth_logout_path
    get farms_path
    assert_redirected_to auth_login_path
  end

  test "should get new when authenticated" do
    get new_farm_path
    assert_response :success
    assert_select "h1", "新しい農場を追加"
    assert_select "form"
    assert_select "input[name='farm[name]']"
    assert_select "input[name='farm[latitude]']"
    assert_select "input[name='farm[longitude]']"
  end

  test "should redirect to login when not authenticated for new" do
    delete auth_logout_path
    get new_farm_path
    assert_redirected_to auth_login_path
  end

  test "should create farm with valid attributes" do
    assert_difference('Farm.count') do
      post farms_path, params: {
        farm: {
          name: "新しい農場",
          latitude: 36.2048,
          longitude: 138.2529
        }
      }
    end
    
    assert_redirected_to farm_path(Farm.last)
    follow_redirect!
    assert_select ".alert", "農場が正常に作成されました。"
  end

  test "should not create farm with invalid attributes" do
    assert_no_difference('Farm.count') do
      post farms_path, params: {
        farm: {
          name: "",
          latitude: 200,
          longitude: 200
        }
      }
    end
    
    assert_response :unprocessable_entity
    assert_select ".error"
  end

  test "should get show when authenticated and farm belongs to user" do
    get farm_path(@farm)
    assert_response :success
    assert_select "h1", @farm.name
    assert_select ".farm-name", @farm.name
  end

  test "should redirect when trying to access another user's farm" do
    other_user = User.create!(
      email: 'other@example.com',
      name: 'Other User',
      google_id: "google_#{SecureRandom.hex(8)}"
    )
    
    other_farm = Farm.create!(
      user: other_user,
      name: "Other Farm",
      latitude: 35.6812,
      longitude: 139.7671
    )
    
    get farm_path(other_farm)
    assert_redirected_to farms_path
    follow_redirect!
    assert_select ".alert", "指定された農場が見つかりません。"
  end

  test "should get edit when authenticated and farm belongs to user" do
    get edit_farm_path(@farm)
    assert_response :success
    assert_select "h1", "農場を編集"
    assert_select "form"
    assert_select "input[name='farm[name]'][value='#{@farm.name}']"
    assert_select "input[name='farm[latitude]'][value='#{@farm.latitude}']"
    assert_select "input[name='farm[longitude]'][value='#{@farm.longitude}']"
  end

  test "should include fields.css and fields.js in edit form" do
    get edit_farm_path(@farm)
    assert_response :success
    
    # Check for fields.css
    assert_select "link[rel='stylesheet'][href*='fields']"
    
    # Check for fields.js (should now exist)
    assert_select "script[src*='fields']"
  end

  test "should successfully load edit page with fields.js asset" do
    # This test verifies that the edit page loads successfully now that fields.js exists
    # Previously this would raise Sprockets::Rails::Helper::AssetNotFound
    
    get edit_farm_path(@farm)
    assert_response :success
    assert_select "h1", "農場を編集"
    assert_select "form"
    assert_select "input[name='farm[name]'][value='#{@farm.name}']"
    assert_select "input[name='farm[latitude]'][value='#{@farm.latitude}']"
    assert_select "input[name='farm[longitude]'][value='#{@farm.longitude}']"
  end

  test "should update farm with valid attributes" do
    patch farm_path(@farm), params: {
      farm: {
        name: "更新された農場",
        latitude: 36.2048,
        longitude: 138.2529
      }
    }
    
    assert_redirected_to farm_path(@farm)
    @farm.reload
    assert_equal "更新された農場", @farm.name
    assert_equal 36.2048, @farm.latitude
    assert_equal 138.2529, @farm.longitude
  end

  test "should not update farm with invalid attributes" do
    original_name = @farm.name
    original_latitude = @farm.latitude
    original_longitude = @farm.longitude
    
    patch farm_path(@farm), params: {
      farm: {
        name: "",
        latitude: 200,
        longitude: 200
      }
    }
    
    assert_response :unprocessable_entity
    @farm.reload
    assert_equal original_name, @farm.name
    assert_equal original_latitude, @farm.latitude
    assert_equal original_longitude, @farm.longitude
  end

  test "should destroy farm when authenticated and farm belongs to user" do
    assert_difference('Farm.count', -1) do
      delete farm_path(@farm)
    end
    
    assert_redirected_to farms_path
    follow_redirect!
    assert_select ".alert", "農場が削除されました。"
  end

  test "should not destroy another user's farm" do
    other_user = User.create!(
      email: 'other@example.com',
      name: 'Other User',
      google_id: "google_#{SecureRandom.hex(8)}"
    )
    
    other_farm = Farm.create!(
      user: other_user,
      name: "Other Farm",
      latitude: 35.6812,
      longitude: 139.7671
    )
    
    assert_no_difference('Farm.count') do
      delete farm_path(other_farm)
    end
    
    assert_redirected_to farms_path
  end

  test "should show map container in new and edit forms" do
    get new_farm_path
    assert_response :success
    assert_select "#map"
    assert_select ".map-container"
    
    # This should now work since fields.js exists
    get edit_farm_path(@farm)
    assert_response :success
    assert_select "#map"
    assert_select ".map-container"
  end

  test "should include Leaflet CSS and JS in new and edit forms" do
    get new_farm_path
    assert_response :success
    assert_select "link[href='/leaflet.css']"
    assert_select "script[src='/leaflet.js']"
    
    # This should now work since fields.js exists
    get edit_farm_path(@farm)
    assert_response :success
    assert_select "link[href='/leaflet.css']"
    assert_select "script[src='/leaflet.js']"
  end

  test "should display farm coordinates in show page" do
    get farm_path(@farm)
    assert_response :success
    assert_select ".info-value", @farm.latitude.to_s
    assert_select ".info-value", @farm.longitude.to_s
  end

  test "should display empty state when no farms exist" do
    Farm.destroy_all
    get farms_path
    assert_response :success
    assert_select ".empty-state"
    assert_select ".empty-state-icon", "🚜"
  end

  test "should display farms in grid layout when farms exist" do
    get farms_path
    assert_response :success
    assert_select ".farms-grid"
    assert_select ".farm-card"
    assert_select ".farm-name", @farm.name
  end
end
