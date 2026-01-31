# frozen_string_literal: true

require "test_helper"

# ApiCrudResponderの動作を既存のコントローラーで検証
class ApiCrudResponderTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @user.generate_api_key!
    @api_key = @user.api_key
  end

  # Api::V1::Masters::FarmsControllerがApiCrudResponderを使用していることを確認
  test "FarmsController includes ApiCrudResponder" do
    assert_includes Api::V1::Masters::FarmsController.included_modules, ApiCrudResponder
  end

  test "respond_to_index renders json array" do
    farm1 = create(:farm, :user_owned, user: @user)
    farm2 = create(:farm, :user_owned, user: @user)

    get api_v1_masters_farms_path,
        headers: { "Accept" => "application/json", "X-API-Key" => @api_key }

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_kind_of Array, json_response
    assert_equal 2, json_response.length
  end

  test "respond_to_show renders json object" do
    farm = create(:farm, :user_owned, user: @user, name: "テスト農場")

    get api_v1_masters_farm_path(farm),
        headers: { "Accept" => "application/json", "X-API-Key" => @api_key }

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal farm.id, json_response["id"]
    assert_equal "テスト農場", json_response["name"]
  end

  test "respond_to_create with valid params returns created status" do
    post api_v1_masters_farms_path,
         params: { farm: { name: "新規農場", region: "jp", latitude: 35.0, longitude: 135.0 } },
         headers: { "Accept" => "application/json", "X-API-Key" => @api_key }

    assert_response :created
    json_response = JSON.parse(response.body)
    assert_equal "新規農場", json_response["name"]
    assert_equal @user.id, json_response["user_id"]
  end

  test "respond_to_create with invalid params returns unprocessable_entity with errors" do
    post api_v1_masters_farms_path,
         params: { farm: { name: "" } },
         headers: { "Accept" => "application/json", "X-API-Key" => @api_key }

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert json_response.key?("errors")
    assert_kind_of Array, json_response["errors"]
  end

  test "respond_to_update with valid params returns ok" do
    farm = create(:farm, :user_owned, user: @user, name: "元の名前")

    patch api_v1_masters_farm_path(farm),
          params: { farm: { name: "更新された名前" } },
          headers: { "Accept" => "application/json", "X-API-Key" => @api_key }

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "更新された名前", json_response["name"]
    assert_equal "更新された名前", farm.reload.name
  end

  test "respond_to_update with invalid params returns unprocessable_entity with errors" do
    farm = create(:farm, :user_owned, user: @user)

    patch api_v1_masters_farm_path(farm),
          params: { farm: { name: "" } },
          headers: { "Accept" => "application/json", "X-API-Key" => @api_key }

    # 現状の API は name 空白時も update を試行し、モデルが無効なら 422 を返す
    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert json_response.key?("errors")
    assert_kind_of Array, json_response["errors"]
  end

  test "respond_to_destroy with valid params returns undo json or no_content" do
    farm = create(:farm, :user_owned, user: @user)

    assert_difference("@user.farms.where(is_reference: false).count", -1) do
      delete api_v1_masters_farm_path(farm),
             headers: { "Accept" => "application/json", "X-API-Key" => @api_key }
    end

    # 現状の API は削除時に undo トークン付き JSON (200) を返す
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response.key?("undo_token")
    assert json_response.key?("undo_path")
  end
end
