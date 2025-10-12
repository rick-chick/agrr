# frozen_string_literal: true

require 'test_helper'

class Api::V1::Farms::FarmApiControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @farm = farms(:one)
    @gateway = Adapters::Farm::Gateways::FarmMemoryGateway.new
    @create_interactor = Domain::Farm::Interactors::FarmCreateInteractor.new(@gateway)
    @find_interactor = Domain::Farm::Interactors::FarmFindInteractor.new(@gateway)
    
    # Mock the interactors in the controller
    @controller = Api::V1::Farms::FarmApiController.new
    @controller.instance_variable_set(:@create_interactor, @create_interactor)
    @controller.instance_variable_set(:@find_interactor, @find_interactor)
    
    # IntegrationTest用にセッションIDを作成
    @session_id = create_session_for(@user)
    @auth_headers = session_cookie_header(@session_id)
  end

  test "should get index" do
    get "/api/v1/farms", headers: @auth_headers
    
    assert_response :success
    assert_equal "application/json", response.media_type
  end

  test "should show farm" do
    get "/api/v1/farms/#{@farm.id}", headers: @auth_headers
    
    assert_response :success
    assert_equal "application/json", response.media_type
    
    json_response = JSON.parse(response.body)
    assert_equal @farm.id, json_response["id"]
    assert_equal @farm.name, json_response["name"]
  end

  test "should create farm" do
    farm_params = {
      name: "新しい農場",
      latitude: 35.6762,
      longitude: 139.6503
    }
    
    post "/api/v1/farms", 
         params: { farm: farm_params },
         headers: @auth_headers
    
    assert_response :created
    assert_equal "application/json", response.media_type
    
    json_response = JSON.parse(response.body)
    assert_equal "新しい農場", json_response["name"]
    assert_not_nil json_response["id"]
  end

  test "should update farm" do
    update_params = {
      name: "更新された農場"
    }
    
    put "/api/v1/farms/#{@farm.id}",
        params: { farm: update_params },
        headers: @auth_headers
    
    assert_response :success
    assert_equal "application/json", response.media_type
    
    json_response = JSON.parse(response.body)
    assert_equal "更新された農場", json_response["name"]
  end

  test "should destroy farm" do
    delete "/api/v1/farms/#{@farm.id}", headers: @auth_headers    
    assert_response :no_content
  end

  test "should return error when farm not found" do
    get "/api/v1/farms/999999", headers: @auth_headers    
    assert_response :not_found
    assert_equal "application/json", response.media_type
    
    json_response = JSON.parse(response.body)
    assert_equal "Farm not found", json_response["error"]
  end

  test "should return validation error for invalid data" do
    invalid_params = {
      name: nil,
      latitude: 91.0
    }
    
    post "/api/v1/farms",
         params: { farm: invalid_params },
         headers: @auth_headers
    
    assert_response :unprocessable_entity
    assert_equal "application/json", response.media_type
    
    json_response = JSON.parse(response.body)
    assert json_response["error"].present?
  end

end
