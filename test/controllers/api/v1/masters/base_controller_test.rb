# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    module Masters
      class BaseControllerTest < ActionDispatch::IntegrationTest
        test "rejects request without api key or session" do
          get api_v1_masters_crops_path, headers: { "Accept" => "application/json" }

          assert_response :unauthorized
          json_response = JSON.parse(response.body)
          assert_equal I18n.t("auth.api.login_required"), json_response["error"]
        end

        test "rejects request with invalid API key" do
          get api_v1_masters_crops_path,
              headers: {
                "Accept" => "application/json",
                "X-API-Key" => "invalid_key"
              }

          assert_response :unauthorized
          json_response = JSON.parse(response.body)
          assert_equal "Invalid API key", json_response["error"]
        end

        test "allows request with valid API key in X-API-Key header" do
          user = create(:user)
          user.generate_api_key!

          get api_v1_masters_crops_path,
              headers: {
                "Accept" => "application/json",
                "X-API-Key" => user.api_key
              }

          assert_response :success
        end

        test "allows request with valid session cookie" do
          user = create(:user)
          session_id = create_session_for(user)

          get api_v1_masters_crops_path,
              headers: { "Accept" => "application/json" }.merge(session_cookie_header(session_id))

          assert_response :success
        end
      end
    end
  end
end
