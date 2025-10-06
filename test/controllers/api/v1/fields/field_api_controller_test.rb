# frozen_string_literal: true

require 'test_helper'

class Api::V1::Fields::FieldApiControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @farm = farms(:one)
    @field = fields(:one)
    @gateway = Adapters::Field::Gateways::FieldMemoryGateway.new
    @create_interactor = Domain::Field::Interactors::FieldCreateInteractor.new(@gateway)
    @find_interactor = Domain::Field::Interactors::FieldFindInteractor.new(@gateway)
    
    # Create authenticated session for tests
    @session = Session.create_for_user(@user)
  end

  test "should get index" do
    get "/api/v1/farms/#{@farm.id}/fields", headers: auth_headers(@user)
    
    assert_response :success
    assert_equal "application/json; charset=utf-8", response.content_type
  end

  test "should show field" do
    get "/api/v1/farms/#{@farm.id}/fields/#{@field.id}", headers: auth_headers(@user)
    
    assert_response :success
    assert_equal "application/json; charset=utf-8", response.content_type
    
    json_response = JSON.parse(response.body)
    assert_equal @field.id, json_response["id"]
    assert_equal @field.name, json_response["name"]
  end

  test "should create field" do
    field_params = {
      name: "新しい圃場",
      latitude: "35.6762",
      longitude: "139.6503",
      description: "テスト用の圃場です"
    }
    
    post "/api/v1/farms/#{@farm.id}/fields", 
         params: { field: field_params },
         headers: auth_headers(@user)
    
    assert_response :created
    assert_equal "application/json; charset=utf-8", response.content_type
    
    json_response = JSON.parse(response.body)
    assert_equal "新しい圃場", json_response["name"]
    assert_not_nil json_response["id"]
  end

  test "should update field" do
    update_params = {
      name: "更新された圃場"
    }
    
    put "/api/v1/farms/#{@farm.id}/fields/#{@field.id}",
        params: { field: update_params },
        headers: auth_headers(@user)
    
    assert_response :success
    assert_equal "application/json; charset=utf-8", response.content_type
    
    json_response = JSON.parse(response.body)
    assert_equal "更新された圃場", json_response["name"]
  end

  test "should destroy field" do
    delete "/api/v1/farms/#{@farm.id}/fields/#{@field.id}", headers: auth_headers(@user)
    
    assert_response :no_content
  end

  test "should return error when field not found" do
    get "/api/v1/farms/#{@farm.id}/fields/999999", headers: auth_headers(@user)
    
    assert_response :not_found
    assert_equal "application/json; charset=utf-8", response.content_type
    
    json_response = JSON.parse(response.body)
    assert_equal "Field not found", json_response["error"]
  end

  test "should return validation error for invalid data" do
    invalid_params = {
      name: nil,
      latitude: 91.0
    }
    
    post "/api/v1/farms/#{@farm.id}/fields",
         params: { field: invalid_params },
         headers: auth_headers(@user)
    
    assert_response :unprocessable_entity
    assert_equal "application/json; charset=utf-8", response.content_type
    
    json_response = JSON.parse(response.body)
    assert json_response["error"].present?
  end

  private

  def auth_headers(user)
    { "Cookie" => "session_id=#{@session.session_id}" }
  end
end
