# frozen_string_literal: true

require "test_helper"

class FieldsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_authenticated_user
    @farm = Farm.create!(
      user: @user,
      name: "テスト農場",
      latitude: 35.6812,
      longitude: 139.7671
    )
    @field = Field.create!(
      farm: @farm,
      user: @user,
      name: "テスト圃場"
    )
  end

  test "should get index when authenticated" do
    get farm_fields_path(@farm)
    assert_response :success
    assert_select "h1", "圃場一覧"
  end

  test "should redirect to login when not authenticated" do
    delete auth_logout_path
    get fields_path
    assert_redirected_to auth_login_path
  end

  test "should get new when authenticated" do
    get new_field_path
    assert_response :success
    assert_select "h1", "新しい圃場を追加"
    assert_select "form"
    assert_select "input[name='field[name]']"
    assert_select "input[name='field[latitude]']"
    assert_select "input[name='field[longitude]']"
  end

  test "should redirect to login when not authenticated for new" do
    delete auth_logout_path
    get new_field_path
    assert_redirected_to auth_login_path
  end

  test "should create field with valid attributes" do
    assert_difference('Field.count') do
      post fields_path, params: {
        field: {
          name: "新しい圃場",
          latitude: 36.2048,
          longitude: 138.2529
        }
      }
    end
    
    assert_redirected_to field_path(Field.last)
    follow_redirect!
    assert_select ".alert", "圃場が正常に作成されました。"
  end

  test "should not create field with invalid attributes" do
    assert_no_difference('Field.count') do
      post fields_path, params: {
        field: {
          name: "",
          latitude: 200,
          longitude: 200
        }
      }
    end
    
    assert_response :unprocessable_entity
    assert_select ".error"
  end

  test "should get show when authenticated and field belongs to user" do
    get field_path(@field)
    assert_response :success
    assert_select "h1", @field.display_name
    assert_select ".field-name", @field.name
  end

  test "should redirect when trying to access another user's field" do
    other_user = User.create!(
      email: 'other@example.com',
      name: 'Other User',
      google_id: "google_#{SecureRandom.hex(8)}"
    )
    
    other_field = Field.create!(
      user: other_user,
      name: "Other Field",
      latitude: 35.6812,
      longitude: 139.7671
    )
    
    get field_path(other_field)
    assert_redirected_to fields_path
    follow_redirect!
    assert_select ".alert", "指定された圃場が見つかりません。"
  end

  test "should get edit when authenticated and field belongs to user" do
    get edit_field_path(@field)
    assert_response :success
    assert_select "h1", "圃場を編集"
    assert_select "form"
    assert_select "input[name='field[name]'][value='#{@field.name}']"
    assert_select "input[name='field[latitude]'][value='#{@field.latitude}']"
    assert_select "input[name='field[longitude]'][value='#{@field.longitude}']"
  end

  test "should update field with valid attributes" do
    patch field_path(@field), params: {
      field: {
        name: "更新された圃場",
        latitude: 36.2048,
        longitude: 138.2529
      }
    }
    
    assert_redirected_to field_path(@field)
    @field.reload
    assert_equal "更新された圃場", @field.name
    assert_equal 36.2048, @field.latitude
    assert_equal 138.2529, @field.longitude
  end

  test "should not update field with invalid attributes" do
    original_name = @field.name
    original_latitude = @field.latitude
    original_longitude = @field.longitude
    
    patch field_path(@field), params: {
      field: {
        name: "",
        latitude: 200,
        longitude: 200
      }
    }
    
    assert_response :unprocessable_entity
    @field.reload
    assert_equal original_name, @field.name
    assert_equal original_latitude, @field.latitude
    assert_equal original_longitude, @field.longitude
  end

  test "should destroy field when authenticated and field belongs to user" do
    assert_difference('Field.count', -1) do
      delete field_path(@field)
    end
    
    assert_redirected_to fields_path
    follow_redirect!
    assert_select ".alert", "圃場が削除されました。"
  end

  test "should not destroy another user's field" do
    other_user = User.create!(
      email: 'other@example.com',
      name: 'Other User',
      google_id: "google_#{SecureRandom.hex(8)}"
    )
    
    other_field = Field.create!(
      user: other_user,
      name: "Other Field",
      latitude: 35.6812,
      longitude: 139.7671
    )
    
    assert_no_difference('Field.count') do
      delete field_path(other_field)
    end
    
    assert_redirected_to fields_path
  end

  test "should show map container in new and edit forms" do
    get new_field_path
    assert_response :success
    assert_select "#map"
    assert_select ".map-container"
    
    get edit_field_path(@field)
    assert_response :success
    assert_select "#map"
    assert_select ".map-container"
  end

  test "should include Leaflet CSS and JS in new and edit forms" do
    get new_field_path
    assert_response :success
    assert_select "link[href='/leaflet.css']"
    assert_select "script[src='/leaflet.js']"
    
    get edit_field_path(@field)
    assert_response :success
    assert_select "link[href='/leaflet.css']"
    assert_select "script[src='/leaflet.js']"
  end

  test "should display field coordinates in show page" do
    get field_path(@field)
    assert_response :success
    assert_select ".info-value", @field.latitude.to_s
    assert_select ".info-value", @field.longitude.to_s
  end

  test "should display empty state when no fields exist" do
    Field.destroy_all
    get fields_path
    assert_response :success
    assert_select ".empty-state"
    assert_select ".empty-state-icon", "🌾"
  end

  test "should display fields in grid layout when fields exist" do
    get fields_path
    assert_response :success
    assert_select ".fields-grid"
    assert_select ".field-card"
    assert_select ".field-name", @field.display_name
  end
end
