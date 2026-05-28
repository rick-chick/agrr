# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    module Masters
      class BaseControllerExtractApiKeyTest < ActionDispatch::IntegrationTest
        setup do
          @user = create(:user)
          @user.generate_api_key!
        end

        test "accepts api key from Authorization Bearer header" do
          get api_v1_masters_crops_path,
              headers: {
                "Accept" => "application/json",
                "Authorization" => "Bearer #{@user.api_key}"
              }

          assert_response :success
        end

        test "accepts api key from query parameter" do
          get api_v1_masters_crops_path(api_key: @user.api_key),
              headers: { "Accept" => "application/json" }

          assert_response :success
        end
      end
    end
  end
end
