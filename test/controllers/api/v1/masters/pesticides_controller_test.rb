# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    module Masters
      class PesticidesControllerTest < ActionDispatch::IntegrationTest
        setup do
          @user = create(:user)
          @user.generate_api_key!
          @api_key = @user.api_key
          @crop = create(:crop, :user_owned, user: @user)
          @pest = create(:pest, :user_owned, user: @user)
        end

        test "should get index" do
          pesticide1 = create(:pesticide, :user_owned, user: @user, crop: @crop, pest: @pest)
          pesticide2 = create(:pesticide, :user_owned, user: @user, crop: @crop, pest: @pest)
          # 参照農薬は含まれない
          reference_pesticide = create(:pesticide, :reference, crop: @crop, pest: @pest)
          # 他のユーザーの農薬は含まれない
          other_user = create(:user)
          other_crop = create(:crop, :user_owned, user: other_user)
          other_pest = create(:pest, :user_owned, user: other_user)
          other_pesticide = create(:pesticide, :user_owned, user: other_user, crop: other_crop, pest: other_pest)

          get api_v1_masters_pesticides_path,
              headers: {
                "Accept" => "application/json",
                "X-API-Key" => @api_key
              }

          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal 2, json_response.length
          pesticide_ids = json_response.map { |p| p["id"] }
          assert_includes pesticide_ids, pesticide1.id
          assert_includes pesticide_ids, pesticide2.id
          assert_not_includes pesticide_ids, reference_pesticide.id
          assert_not_includes pesticide_ids, other_pesticide.id
        end

        test "should show pesticide" do
          pesticide = create(:pesticide, :user_owned, user: @user, crop: @crop, pest: @pest, name: "テスト農薬")

          get api_v1_masters_pesticide_path(pesticide),
              headers: {
                "Accept" => "application/json",
                "X-API-Key" => @api_key
              }

          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal pesticide.id, json_response["id"]
          assert_equal "テスト農薬", json_response["name"]
        end

        test "should not show other user's pesticide" do
          other_user = create(:user)
          other_crop = create(:crop, :user_owned, user: other_user)
          other_pest = create(:pest, :user_owned, user: other_user)
          other_pesticide = create(:pesticide, :user_owned, user: other_user, crop: other_crop, pest: other_pest)

          get api_v1_masters_pesticide_path(other_pesticide),
              headers: {
                "Accept" => "application/json",
                "X-API-Key" => @api_key
              }

          assert_response :forbidden
          json_response = JSON.parse(response.body)
          assert_equal I18n.t("pesticides.flash.no_permission"), json_response["error"]
        end

        test "should create pesticide" do
          assert_difference("@user.pesticides.where(is_reference: false).count", 1) do
            post api_v1_masters_pesticides_path,
                 params: {
                   pesticide: {
                     name: "新規農薬",
                     active_ingredient: "テスト成分",
                     crop_id: @crop.id,
                     pest_id: @pest.id
                   }
                 },
                 headers: {
                   "Accept" => "application/json",
                   "X-API-Key" => @api_key
                 }
          end

          assert_response :created
          json_response = JSON.parse(response.body)
          assert_equal "新規農薬", json_response["name"]
          assert_equal @user.id, json_response["user_id"]
          assert_equal false, json_response["is_reference"]
        end

        test "should update pesticide" do
          pesticide = create(:pesticide, :user_owned, user: @user, crop: @crop, pest: @pest, name: "元の名前")

          patch api_v1_masters_pesticide_path(pesticide),
                params: {
                  pesticide: {
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

        test "should not update other user's pesticide" do
          other_user = create(:user)
          other_crop = create(:crop, :user_owned, user: other_user)
          other_pest = create(:pest, :user_owned, user: other_user)
          other_pesticide = create(:pesticide, :user_owned, user: other_user, crop: other_crop, pest: other_pest, name: "他のユーザーの農薬")

          patch api_v1_masters_pesticide_path(other_pesticide),
                params: {
                  pesticide: {
                    name: "変更しようとした名前"
                  }
                },
                headers: {
                  "Accept" => "application/json",
                  "X-API-Key" => @api_key
                }

          assert_response :forbidden

          other_pesticide.reload
          assert_equal "他のユーザーの農薬", other_pesticide.name
        end

        test "should destroy pesticide" do
          pesticide = create(:pesticide, :user_owned, user: @user, crop: @crop, pest: @pest)

          assert_difference("@user.pesticides.where(is_reference: false).count", -1) do
            delete api_v1_masters_pesticide_path(pesticide),
                   headers: {
                     "Accept" => "application/json",
                     "X-API-Key" => @api_key
                   }
          end

          assert_response :no_content
        end

        test "should not destroy other user's pesticide" do
          other_user = create(:user)
          other_crop = create(:crop, :user_owned, user: other_user)
          other_pest = create(:pest, :user_owned, user: other_user)
          other_pesticide = create(:pesticide, :user_owned, user: other_user, crop: other_crop, pest: other_pest)

          assert_no_difference("Pesticide.count") do
            delete api_v1_masters_pesticide_path(other_pesticide),
                   headers: {
                     "Accept" => "application/json",
                     "X-API-Key" => @api_key
                   }
          end

          assert_response :forbidden
        end
      end
    end
  end
end
