# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    module Masters
      class CropsControllerTest < ActionDispatch::IntegrationTest
        test "includes ApiCrudResponder" do
          assert_includes Api::V1::Masters::CropsController.included_modules, ApiCrudResponder
        end
        setup do
          @user = create(:user)
          @user.generate_api_key!
          @api_key = @user.api_key
        end

        test "should get index" do
          crop1 = create(:crop, :user_owned, user: @user)
          crop2 = create(:crop, :user_owned, user: @user)
          # 参照作物は含まれない
          reference_crop = create(:crop, :reference)
          # 他のユーザーの作物は含まれない
          other_user = create(:user)
          other_crop = create(:crop, :user_owned, user: other_user)

          get api_v1_masters_crops_path, 
              headers: { 
                "Accept" => "application/json",
                "X-API-Key" => @api_key
              }

          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal 2, json_response.length
          crop_ids = json_response.map { |c| c["id"] }
          assert_includes crop_ids, crop1.id
          assert_includes crop_ids, crop2.id
          assert_not_includes crop_ids, reference_crop.id
          assert_not_includes crop_ids, other_crop.id
        end

        test "should show crop" do
          crop = create(:crop, :user_owned, user: @user, name: "テスト作物")

          get api_v1_masters_crop_path(crop),
              headers: {
                "Accept" => "application/json",
                "X-API-Key" => @api_key
              }

          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal crop.id, json_response["id"]
          assert_equal "テスト作物", json_response["name"]
        end

        test "should show crop with crop_stages" do
          crop = create(:crop, :user_owned, user: @user)
          crop_stage = create(:crop_stage, crop: crop, name: "発芽期", order: 1)

          get api_v1_masters_crop_path(crop),
              headers: {
                "Accept" => "application/json",
                "X-API-Key" => @api_key
              }

          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal crop.id, json_response["id"]
          # RED: crop_stages should be included but currently missing
          assert json_response["crop_stages"].present?, "crop_stages should be included in crop response"
          assert_equal 1, json_response["crop_stages"].length
          assert_equal crop_stage.id, json_response["crop_stages"][0]["id"]
          assert_equal "発芽期", json_response["crop_stages"][0]["name"]
        end

        test "should not show other user's crop" do
          other_user = create(:user)
          other_crop = create(:crop, :user_owned, user: other_user)

          get api_v1_masters_crop_path(other_crop),
              headers: {
                "Accept" => "application/json",
                "X-API-Key" => @api_key
              }

          assert_response :forbidden
          json_response = JSON.parse(response.body)
          assert_equal I18n.t("crops.flash.no_permission"), json_response["error"]
        end

        test "should create crop" do
          assert_difference("@user.crops.where(is_reference: false).count", 1) do
            post api_v1_masters_crops_path, 
                 params: { 
                   crop: {
                     name: "新規作物",
                     variety: "テスト品種",
                     area_per_unit: 0.25,
                     revenue_per_area: 5000.0
                   }
                 },
                 headers: { 
                   "Accept" => "application/json",
                   "X-API-Key" => @api_key
                 }
          end

          assert_response :created
          json_response = JSON.parse(response.body)
          assert_equal "新規作物", json_response["name"]
          assert_equal "テスト品種", json_response["variety"]
          assert_equal @user.id, json_response["user_id"]
          assert_equal false, json_response["is_reference"]
        end

        test "should not create crop with invalid params" do
          assert_no_difference("@user.crops.count") do
            post api_v1_masters_crops_path, 
                 params: { 
                   crop: {
                     name: nil
                   }
                 },
                 headers: { 
                   "Accept" => "application/json",
                   "X-API-Key" => @api_key
                 }
          end

          assert_response :unprocessable_entity
          json_response = JSON.parse(response.body)
          assert json_response["errors"].any?
        end

        test "should update crop" do
          crop = create(:crop, :user_owned, user: @user, name: "元の名前")

          patch api_v1_masters_crop_path(crop), 
                params: { 
                  crop: {
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
          
          crop.reload
          assert_equal "更新された名前", crop.name
        end

        test "should not update other user's crop" do
          other_user = create(:user)
          other_crop = create(:crop, :user_owned, user: other_user, name: "他のユーザーの作物")

          patch api_v1_masters_crop_path(other_crop),
                params: {
                  crop: {
                    name: "変更しようとした名前"
                  }
                },
                headers: {
                  "Accept" => "application/json",
                  "X-API-Key" => @api_key
                }

          assert_response :forbidden
          
          other_crop.reload
          assert_equal "他のユーザーの作物", other_crop.name
        end

        test "should destroy crop" do
          crop = create(:crop, :user_owned, user: @user)

          assert_difference("@user.crops.where(is_reference: false).count", -1) do
            delete api_v1_masters_crop_path(crop), 
                   headers: { 
                     "Accept" => "application/json",
                     "X-API-Key" => @api_key
                   }
          end

          assert_response :ok
          json = response.parsed_body
          assert json["undo_token"].present?
          assert json["undo_path"].present?
        end

        test "should not destroy other user's crop" do
          other_user = create(:user)
          other_crop = create(:crop, :user_owned, user: other_user)

          assert_no_difference("::Crop.count") do
            delete api_v1_masters_crop_path(other_crop),
                   headers: {
                     "Accept" => "application/json",
                     "X-API-Key" => @api_key
                   }
          end

          assert_response :forbidden
        end

        test "should return 422 when destroying crop that is in use (cultivation_plan_crops)" do
          crop = create(:crop, :user_owned, user: @user)
          plan = create(:cultivation_plan, user: @user)
          create(:cultivation_plan_crop, cultivation_plan: plan, crop: crop)

          assert_no_difference("::Crop.count") do
            delete api_v1_masters_crop_path(crop),
                   headers: {
                     "Accept" => "application/json",
                     "X-API-Key" => @api_key
                   }
          end

          assert_response :unprocessable_entity
          json = response.parsed_body
          assert json["error"].present?
          assert_match(/使用されているため削除できません/, json["error"])
        end
      end
    end
  end
end
