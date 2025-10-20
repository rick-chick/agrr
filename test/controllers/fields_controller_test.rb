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
    assert_select "h1", "テスト農場 - 圃場一覧"
  end

  test "should redirect to login when not authenticated" do
    delete auth_logout_path
    get farm_fields_path(@farm)
    assert_redirected_to auth_login_path
  end

  test "should get new when authenticated" do
    get new_farm_field_path(@farm)
    assert_response :success
    assert_select "h1", "テスト農場 - 新しい圃場を追加"
    assert_select "form"
    assert_select "input[name='field[name]']"
    assert_select "input[name='field[area]']"
    assert_select "input[name='field[daily_fixed_cost]']"
  end

  test "should display new page in Japanese" do
    get new_farm_field_path(@farm), headers: { 'Accept-Language': 'ja' }
    assert_response :success
    assert_select "h1", "テスト農場 - 新しい圃場を追加"
    assert_select "label", text: "圃場名"
    assert_select "input[placeholder='例: 北側の田んぼ']"
    assert_select "label", text: "面積（㎡）"
    assert_select "label", text: "日次固定費用（円）"
    assert_select "input[type='submit'][value='圃場を作成']"
  end

  test "should display new page in English" do
    get new_farm_field_path(@farm, locale: 'us')
    assert_response :success
    assert_select "h1", /Add New Field/
    assert_select "label", text: "Field Name"
    assert_select "input[placeholder='e.g., North Rice Field']"
    assert_select "label", text: "Area (㎡)"
    assert_select "label", text: "Daily Fixed Cost (¥)"
    assert_select "input[type='submit'][value='Create Field']"
  end

  test "should display new page in Hindi" do
    get new_farm_field_path(@farm, locale: 'in')
    assert_response :success
    assert_select "h1", /नया खेत क्षेत्र जोड़ें/
    assert_select "label", text: "खेत क्षेत्र नाम"
    assert_select "input[placeholder='उदाहरण: उत्तरी धान खेत']"
    assert_select "label", text: "क्षेत्रफल (वर्ग मीटर)"
    assert_select "label", text: "दैनिक निश्चित लागत (₹)"
    assert_select "input[type='submit'][value='खेत क्षेत्र बनाएं']"
  end

  test "should include i18n data attributes for JavaScript in Japanese" do
    get new_farm_field_path(@farm), headers: { 'Accept-Language': 'ja' }
    assert_response :success
    assert_select "body[data-fields-validation-coordinates-numeric]"
    assert_select "body[data-fields-validation-latitude-range]"
    assert_select "body[data-fields-validation-longitude-range]"
  end

  test "should include correct Japanese validation messages in data attributes" do
    get new_farm_field_path(@farm, locale: 'ja')
    assert_response :success
    
    # HTMLをパースしてdata属性の値を確認
    doc = Nokogiri::HTML(response.body)
    body = doc.at_css('body')
    
    assert_equal "緯度と経度は数値で入力してください。", body['data-fields-validation-coordinates-numeric']
    assert_equal "緯度は-90から90の間で入力してください。", body['data-fields-validation-latitude-range']
    assert_equal "経度は-180から180の間で入力してください。", body['data-fields-validation-longitude-range']
  end

  test "should include correct English validation messages in data attributes" do
    get new_farm_field_path(@farm, locale: 'us')
    assert_response :success
    
    doc = Nokogiri::HTML(response.body)
    body = doc.at_css('body')
    
    assert_equal "Latitude and longitude must be numeric values.", body['data-fields-validation-coordinates-numeric']
    assert_equal "Latitude must be between -90 and 90.", body['data-fields-validation-latitude-range']
    assert_equal "Longitude must be between -180 and 180.", body['data-fields-validation-longitude-range']
  end

  test "should include correct Hindi validation messages in data attributes" do
    get new_farm_field_path(@farm, locale: 'in')
    assert_response :success
    
    doc = Nokogiri::HTML(response.body)
    body = doc.at_css('body')
    
    assert_equal "अक्षांश और देशांतर संख्यात्मक मान होने चाहिए।", body['data-fields-validation-coordinates-numeric']
    assert_equal "अक्षांश -90 और 90 के बीच होना चाहिए।", body['data-fields-validation-latitude-range']
    assert_equal "देशांतर -180 और 180 के बीच होना चाहिए।", body['data-fields-validation-longitude-range']
  end

  test "should redirect to login when not authenticated for new" do
    delete auth_logout_path
    get new_farm_field_path(@farm)
    assert_redirected_to auth_login_path
  end

  test "should create field with valid attributes" do
    assert_difference('Field.count') do
      post farm_fields_path(@farm), params: {
        field: {
          name: "新しい圃場",
          latitude: 36.2048,
          longitude: 138.2529
        }
      }
    end
    
    assert_redirected_to farm_field_path(@farm, Field.last)
    follow_redirect!
    assert_select ".alert", "圃場が正常に作成されました。"
  end

  test "should create field with area and daily_fixed_cost" do
    assert_difference('Field.count') do
      post farm_fields_path(@farm), params: {
        field: {
          name: "新しい圃場",
          area: 1000.0,
          daily_fixed_cost: 5000.0
        }
      }
    end
    
    new_field = Field.last
    assert_equal 1000.0, new_field.area
    assert_equal 5000.0, new_field.daily_fixed_cost
    assert_redirected_to farm_field_path(@farm, new_field)
  end

  test "should not create field with invalid attributes" do
    assert_no_difference('Field.count') do
      post farm_fields_path(@farm), params: {
        field: {
          name: "",
          latitude: 200,
          longitude: 200
        }
      }
    end
    
    assert_response :unprocessable_entity
    # フォームが再表示されることを確認
    assert_select "form"
  end

  test "should not create field with invalid area" do
    assert_no_difference('Field.count') do
      post farm_fields_path(@farm), params: {
        field: {
          name: "新しい圃場",
          area: -100
        }
      }
    end
    
    assert_response :unprocessable_entity
    assert_select "form"
  end

  test "should not create field with invalid daily_fixed_cost" do
    assert_no_difference('Field.count') do
      post farm_fields_path(@farm), params: {
        field: {
          name: "新しい圃場",
          daily_fixed_cost: -1000
        }
      }
    end
    
    assert_response :unprocessable_entity
    assert_select "form"
  end

  test "should get show when authenticated and field belongs to user" do
    get farm_field_path(@farm, @field)
    assert_response :success
    assert_select "h1", @field.display_name
    assert_select ".info-value", @field.name
  end

  test "should redirect when trying to access another user's field" do
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
    other_field = Field.create!(
      farm: other_farm,
      user: other_user,
      name: "Other Field",
      latitude: 35.6812,
      longitude: 139.7671
    )
    
    # 他のユーザーのfarmにアクセスしようとするとfarms_pathにリダイレクト
    get farm_field_path(other_farm, other_field)
    assert_redirected_to farms_path
    follow_redirect!
    assert_select ".alert", "指定された農場が見つかりません。"
  end

  test "should get edit when authenticated and field belongs to user" do
    @field.update!(area: 1000.0, daily_fixed_cost: 5000.0)
    get edit_farm_field_path(@farm, @field)
    assert_response :success
    assert_select "h1", text: /圃場を編集/
    assert_select "form"
    assert_select "input[name='field[name]'][value='#{@field.name}']"
    assert_select "input[name='field[area]']"
    assert_select "input[name='field[daily_fixed_cost]']"
  end

  test "should update field with valid attributes" do
    patch farm_field_path(@farm, @field), params: {
      field: {
        name: "更新された圃場",
        latitude: 36.2048,
        longitude: 138.2529
      }
    }
    
    assert_redirected_to farm_field_path(@farm, @field)
    @field.reload
    assert_equal "更新された圃場", @field.name
    assert_equal 36.2048, @field.latitude
    assert_equal 138.2529, @field.longitude
  end

  test "should update field with area and daily_fixed_cost" do
    patch farm_field_path(@farm, @field), params: {
      field: {
        area: 1500.0,
        daily_fixed_cost: 6000.0
      }
    }
    
    assert_redirected_to farm_field_path(@farm, @field)
    @field.reload
    assert_equal 1500.0, @field.area
    assert_equal 6000.0, @field.daily_fixed_cost
  end

  test "should not update field with invalid attributes" do
    original_name = @field.name
    original_latitude = @field.latitude
    original_longitude = @field.longitude
    
    patch farm_field_path(@farm, @field), params: {
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
      delete farm_field_path(@farm, @field)
    end
    
    assert_redirected_to farm_fields_path(@farm)
    follow_redirect!
    assert_select ".alert", "圃場が削除されました。"
  end

  test "should not destroy another user's field" do
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
    other_field = Field.create!(
      farm: other_farm,
      user: other_user,
      name: "Other Field",
      latitude: 35.6812,
      longitude: 139.7671
    )
    
    assert_no_difference('Field.count') do
      delete farm_field_path(other_farm, other_field)
    end
    
    # 他のユーザーのfarmにアクセスしようとするとfarms_pathにリダイレクト
    assert_redirected_to farms_path
  end

  # Note: 地図機能は現在実装されていないため、これらのテストはスキップ
  # test "should show map container in new and edit forms" - 地図機能未実装
  # test "should include Leaflet CSS and JS in new and edit forms" - 地図機能未実装
  # test "should display field coordinates in show page" - 座標表示未実装

  test "should display empty state when no fields exist" do
    Field.destroy_all
    get farm_fields_path(@farm)
    assert_response :success
    assert_select ".empty-state"
    assert_select ".empty-state-icon", "🌾"
  end

  test "should display fields in grid layout when fields exist" do
    get farm_fields_path(@farm)
    assert_response :success
    assert_select ".fields-grid"
    assert_select ".field-card"
    assert_select ".field-name", @field.display_name
  end
end
