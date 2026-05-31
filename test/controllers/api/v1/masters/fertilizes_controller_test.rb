# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    module Masters
      class FertilizesControllerTest < ActionDispatch::IntegrationTest
        setup do
          @user = create(:user)
          @user.generate_api_key!
          @api_key = @user.api_key
        end

        test "should get index" do
          fertilize1 = create(:fertilize, :user_owned, user: @user)
          fertilize2 = create(:fertilize, :user_owned, user: @user)

          get api_v1_masters_fertilizes_path,
              headers: {
                "Accept" => "application/json",
                "X-API-Key" => @api_key
              }

          assert_response :success
          json_response = JSON.parse(response.body)
          assert_kind_of Array, json_response
          assert_equal [ fertilize1.id, fertilize2.id ].sort, json_response.map { |f| f["id"] }.sort
        end

        test "should show fertilize" do
          fertilize = create(:fertilize, :user_owned, user: @user, name: "テスト肥料")

          get api_v1_masters_fertilize_path(fertilize),
              headers: {
                "Accept" => "application/json",
                "X-API-Key" => @api_key
              }

          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal fertilize.id, json_response["id"]
          assert_equal "テスト肥料", json_response["name"]
        end

        test "create returns 422 when name is missing" do
          assert_no_difference("@user.fertilizes.where(is_reference: false).count") do
            post api_v1_masters_fertilizes_path,
                 params: { fertilize: { name: "" } },
                 as: :json,
                 headers: {
                   "Accept" => "application/json",
                   "X-API-Key" => @api_key
                 }
          end

          assert_response :unprocessable_entity
          json = JSON.parse(response.body)
          assert_includes json["errors"], "name is required"
        end

        test "should create fertilize" do
          assert_difference("@user.fertilizes.where(is_reference: false).count", 1) do
            post api_v1_masters_fertilizes_path,
                 params: {
                   fertilize: {
                     name: "新規肥料",
                     n: 10.0,
                     p: 5.0,
                     k: 5.0,
                     package_size: 25.0
                   }
                 },
                 as: :json,
                 headers: {
                   "Accept" => "application/json",
                   "X-API-Key" => @api_key
                 }
          end

          assert_response :created
          json_response = JSON.parse(response.body)
          assert_equal "新規肥料", json_response["name"]
          assert_equal @user.id, json_response["user_id"]
        end

        test "should update fertilize" do
          fertilize = create(:fertilize, :user_owned, user: @user, name: "元の名前")

          patch api_v1_masters_fertilize_path(fertilize),
                params: {
                  fertilize: {
                    name: "更新された名前"
                  }
                },
                as: :json,
                headers: {
                  "Accept" => "application/json",
                  "X-API-Key" => @api_key
                }

          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal "更新された名前", json_response["name"]
        end

        test "should destroy fertilize" do
          fertilize = create(:fertilize, :user_owned, user: @user)

          assert_difference("@user.fertilizes.where(is_reference: false).count", -1) do
            delete api_v1_masters_fertilize_path(fertilize),
                   headers: {
                     "Accept" => "application/json",
                     "X-API-Key" => @api_key
                   }
          end

          assert_response :success
          json_response = JSON.parse(response.body)
          assert json_response.key?("undo_token")
          assert json_response.key?("toast_message")
          assert json_response.key?("undo_path")
        end

      end
    end
  end
end
