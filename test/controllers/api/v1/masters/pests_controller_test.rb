# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    module Masters
      class PestsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @user = create(:user)
          @user.generate_api_key!
          @api_key = @user.api_key
        end

        test "should get index" do
          pest1 = create(:pest, :user_owned, user: @user)
          pest2 = create(:pest, :user_owned, user: @user)
          # 参照害虫は含まれない
          reference_pest = create(:pest, :reference)
          # 他のユーザーの害虫は含まれない
          other_user = create(:user)
          other_pest = create(:pest, :user_owned, user: other_user)

          get api_v1_masters_pests_path, 
              headers: { 
                "Accept" => "application/json",
                "X-API-Key" => @api_key
              }

          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal 2, json_response.length
          pest_ids = json_response.map { |p| p["id"] }
          assert_includes pest_ids, pest1.id
          assert_includes pest_ids, pest2.id
          assert_not_includes pest_ids, reference_pest.id
          assert_not_includes pest_ids, other_pest.id
        end

        test "should show pest" do
          pest = create(:pest, :user_owned, user: @user, name: "テスト害虫")

          get api_v1_masters_pest_path(pest), 
              headers: { 
                "Accept" => "application/json",
                "X-API-Key" => @api_key
              }

          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal pest.id, json_response["id"]
          assert_equal "テスト害虫", json_response["name"]
        end

        test "should create pest" do
          assert_difference("@user.pests.where(is_reference: false).count", 1) do
            post api_v1_masters_pests_path, 
                 params: { 
                   pest: {
                     name: "新規害虫",
                     name_scientific: "Testus pestus",
                     family: "テスト科"
                   }
                 },
                 headers: { 
                   "Accept" => "application/json",
                   "X-API-Key" => @api_key
                 }
          end

          assert_response :created
          json_response = JSON.parse(response.body)
          assert_equal "新規害虫", json_response["name"]
          assert_equal @user.id, json_response["user_id"]
          assert_equal false, json_response["is_reference"]
        end

        test "should update pest" do
          pest = create(:pest, :user_owned, user: @user, name: "元の名前")

          patch api_v1_masters_pest_path(pest), 
                params: { 
                  pest: {
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

        test "should destroy pest" do
          pest = create(:pest, :user_owned, user: @user)

          assert_difference("@user.pests.where(is_reference: false).count", -1) do
            delete api_v1_masters_pest_path(pest), 
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
