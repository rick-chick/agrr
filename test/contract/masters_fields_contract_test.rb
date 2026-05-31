# frozen_string_literal: true

require "test_helper"
require_relative "contract_test_case"

class MastersFieldsContractTest < ContractTestCase
  setup do
    @user = create(:user)
    @user.generate_api_key!
    @api_key = @user.api_key
    @session_id = contract_session_id_for(@user)
    @farm = create(:farm, :user_owned, user: @user)
  end

  def rust_headers
    { "X-API-Key" => @api_key }
  end

  test "should get index for farm fields" do
    field1 = create(:field, farm: @farm, user: @user)
    field2 = create(:field, farm: @farm, user: @user)
    other_farm = create(:farm, :user_owned, user: @user)
    other_field = create(:field, farm: other_farm, user: @user)

    if rust_contract?
      response = rust_get(
        "/api/v1/masters/farms/#{@farm.id}/fields",
        headers: rust_headers
      )
      assert_equal 200, response.code.to_i, response.body
      json = JSON.parse(response.body)
    else
      get api_v1_masters_farm_fields_path(@farm),
          headers: { "Accept" => "application/json", "X-API-Key" => @api_key }
      assert_response :success
      json = JSON.parse(response.body)
    end

    assert_equal 2, json.length
    field_ids = json.map { |f| f["id"] }
    assert_includes field_ids, field1.id
    assert_includes field_ids, field2.id
    assert_not_includes field_ids, other_field.id
  end

  test "should return forbidden when listing fields for another users farm" do
    other_user = create(:user)
    other_farm = create(:farm, :user_owned, user: other_user)

    if rust_contract?
      response = rust_get(
        "/api/v1/masters/farms/#{other_farm.id}/fields",
        headers: rust_headers
      )
      assert_equal 403, response.code.to_i, response.body
    else
      get api_v1_masters_farm_fields_path(other_farm),
          headers: { "Accept" => "application/json", "X-API-Key" => @api_key }
      assert_response :forbidden
    end
  end

  test "should show field" do
    field = create(:field, farm: @farm, user: @user, name: "テスト圃場")

    if rust_contract?
      response = rust_get(
        "/api/v1/masters/fields/#{field.id}",
        headers: rust_headers
      )
      assert_equal 200, response.code.to_i, response.body
      json = JSON.parse(response.body)
    else
      get api_v1_masters_field_path(field),
          headers: { "Accept" => "application/json", "X-API-Key" => @api_key }
      assert_response :success
      json = JSON.parse(response.body)
    end

    assert_equal field.id, json["id"]
    assert_equal "テスト圃場", json["name"]
  end

  test "should create field" do
    if rust_contract?
      response = rust_post(
        "/api/v1/masters/farms/#{@farm.id}/fields",
        headers: rust_headers,
        body: {
          field: {
            name: "新規圃場",
            area: 100.0,
            daily_fixed_cost: 500.0
          }
        }
      )
      assert_equal 201, response.code.to_i, response.body
      json = JSON.parse(response.body)
    else
      post api_v1_masters_farm_fields_path(@farm),
           params: {
             field: { name: "新規圃場", area: 100.0, daily_fixed_cost: 500.0 }
           },
           headers: { "Accept" => "application/json", "X-API-Key" => @api_key }
      assert_response :created
      json = JSON.parse(response.body)
    end

    assert_equal "新規圃場", json["name"]
    assert_equal @farm.id, json["farm_id"]
  end

  test "should update field" do
    field = create(:field, farm: @farm, user: @user, name: "元の名前")

    if rust_contract?
      response = rust_patch(
        "/api/v1/masters/fields/#{field.id}",
        headers: rust_headers,
        body: { field: { name: "更新された名前" } }
      )
      assert_equal 200, response.code.to_i, response.body
      json = JSON.parse(response.body)
    else
      patch api_v1_masters_field_path(field),
            params: { field: { name: "更新された名前" } },
            headers: { "Accept" => "application/json", "X-API-Key" => @api_key }
      assert_response :success
      json = JSON.parse(response.body)
    end

    assert_equal "更新された名前", json["name"]
  end

  test "should destroy field" do
    field = create(:field, farm: @farm, user: @user)

    if rust_contract?
      response = rust_delete(
        "/api/v1/masters/fields/#{field.id}",
        headers: rust_headers
      )
      assert_equal 200, response.code.to_i, response.body
      json = JSON.parse(response.body)
      assert json.key?("undo_token")
    else
      delete api_v1_masters_field_path(field),
             headers: { "Accept" => "application/json", "X-API-Key" => @api_key }
      assert_response :success
    end
  end
end
