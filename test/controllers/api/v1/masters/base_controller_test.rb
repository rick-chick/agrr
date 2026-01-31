# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    module Masters
      class BaseControllerTest < ActionDispatch::IntegrationTest
        test "should reject request without API key" do
          get api_v1_masters_crops_path, headers: { "Accept" => "application/json" }
          
          assert_response :unauthorized
          json_response = JSON.parse(response.body)
          assert json_response["error"].present?
        end

        test "should reject request with invalid API key" do
          get api_v1_masters_crops_path, 
              headers: { 
                "Accept" => "application/json",
                "X-API-Key" => "invalid_key"
              }
          
          assert_response :unauthorized
          json_response = JSON.parse(response.body)
          assert_equal "Invalid API key", json_response["error"]
        end

        test "should accept request with valid API key in X-API-Key header" do
          user = create(:user)
          user.generate_api_key!
          
          crop = create(:crop, :user_owned, user: user)
          
          get api_v1_masters_crops_path, 
              headers: { 
                "Accept" => "application/json",
                "X-API-Key" => user.api_key
              }
          
          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal 1, json_response.length
          assert_equal crop.id, json_response[0]["id"]
        end

        test "should accept request with valid API key in Authorization header" do
          user = create(:user)
          user.generate_api_key!
          
          crop = create(:crop, :user_owned, user: user)
          
          get api_v1_masters_crops_path, 
              headers: { 
                "Accept" => "application/json",
                "Authorization" => "Bearer #{user.api_key}"
              }
          
          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal 1, json_response.length
          assert_equal crop.id, json_response[0]["id"]
        end

        test "should accept request with valid API key in query parameter" do
          user = create(:user)
          user.generate_api_key!
          
          crop = create(:crop, :user_owned, user: user)
          
          get api_v1_masters_crops_path(api_key: user.api_key), 
              headers: { "Accept" => "application/json" }
          
          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal 1, json_response.length
          assert_equal crop.id, json_response[0]["id"]
        end
      end
    end
  end
end
