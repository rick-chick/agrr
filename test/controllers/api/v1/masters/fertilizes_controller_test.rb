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
          # 参照肥料は含まれない
          reference_fertilize = create(:fertilize, :reference)
          # 他のユーザーの肥料は含まれない
          other_user = create(:user)
          other_fertilize = create(:fertilize, :user_owned, user: other_user)

          get api_v1_masters_fertilizes_path, 
              headers: { 
                "Accept" => "application/json",
                "X-API-Key" => @api_key
              }

          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal 2, json_response.length
          fertilize_ids = json_response.map { |f| f["id"] }
          assert_includes fertilize_ids, fertilize1.id
          assert_includes fertilize_ids, fertilize2.id
          assert_not_includes fertilize_ids, reference_fertilize.id
          assert_not_includes fertilize_ids, other_fertilize.id
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
                 headers: { 
                   "Accept" => "application/json",
                   "X-API-Key" => @api_key
                 }
          end

          assert_response :created
          json_response = JSON.parse(response.body)
          assert_equal "新規肥料", json_response["name"]
          assert_equal 10.0, json_response["n"]
          assert_equal @user.id, json_response["user_id"]
          assert_equal false, json_response["is_reference"]
        end

        test "should update fertilize" do
          fertilize = create(:fertilize, :user_owned, user: @user, name: "元の名前")

          patch api_v1_masters_fertilize_path(fertilize), 
                params: { 
                  fertilize: {
                    name: "更新された名前"
                  }
                },
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

          assert_response :no_content
        end
      end
    end
  end
end
