# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    module Masters
      class FarmsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @user = create(:user)
          @user.generate_api_key!
          @api_key = @user.api_key
        end

        test "includes Farm Views" do
          assert_includes Api::V1::Masters::FarmsController.included_modules, Views::Api::Farm::FarmListView
          assert_includes Api::V1::Masters::FarmsController.included_modules, Views::Api::Farm::FarmDetailView
          assert_includes Api::V1::Masters::FarmsController.included_modules, Views::Api::Farm::FarmCreateView
          assert_includes Api::V1::Masters::FarmsController.included_modules, Views::Api::Farm::FarmUpdateView
          assert_includes Api::V1::Masters::FarmsController.included_modules, Views::Api::Farm::FarmDeleteView
        end

        test "should get index" do
          farm1 = create(:farm, :user_owned, user: @user)
          farm2 = create(:farm, :user_owned, user: @user)
          # 参照農場は含まれない
          reference_farm = create(:farm, :reference)
          # 他のユーザーの農場は含まれない
          other_user = create(:user)
          other_farm = create(:farm, :user_owned, user: other_user)

          get api_v1_masters_farms_path,
              headers: {
                "Accept" => "application/json",
                "X-API-Key" => @api_key
              }

          assert_response :success
          json_response = JSON.parse(response.body)
          farm_ids = json_response.map { |f| f["id"] }
          assert_includes farm_ids, farm1.id
          assert_includes farm_ids, farm2.id
          assert_not_includes farm_ids, reference_farm.id
          assert_not_includes farm_ids, other_farm.id
          assert_operator json_response.length, :>=, 2
        end

        test "admin should get index with reference farms" do
          admin_user = create(:user, :admin)
          admin_user.generate_api_key!
          admin_api_key = admin_user.api_key

          farm1 = create(:farm, :user_owned, user: admin_user)
          farm2 = create(:farm, :user_owned, user: admin_user)
          # 管理者ユーザーは参照農場も含まれる
          reference_farm = create(:farm, :reference)
          # 他のユーザーの農場は含まれない
          other_user = create(:user)
          other_farm = create(:farm, :user_owned, user: other_user)

          get api_v1_masters_farms_path,
              headers: {
                "Accept" => "application/json",
                "X-API-Key" => admin_api_key
              }

          assert_response :success
          json_response = JSON.parse(response.body)
          farm_ids = json_response.map { |f| f["id"] }
          assert_includes farm_ids, farm1.id
          assert_includes farm_ids, farm2.id
          assert_includes farm_ids, reference_farm.id
          assert_not_includes farm_ids, other_farm.id
          assert_operator json_response.length, :>=, 3
        end

        test "should show farm" do
          farm = create(:farm, :user_owned, user: @user, name: "テスト農場")

          get api_v1_masters_farm_path(farm), 
              headers: { 
                "Accept" => "application/json",
                "X-API-Key" => @api_key
              }

          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal farm.id, json_response["id"]
          assert_equal "テスト農場", json_response["name"]
        end

        test "should create farm" do
          assert_difference("@user.farms.where(is_reference: false).count", 1) do
            post api_v1_masters_farms_path,
                 params: {
                   farm: {
                     name: "新規農場",
                     region: "関東",
                     latitude: 35.6812,
                     longitude: 139.7671
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
          assert_equal "新規農場", json_response["name"]
          assert_equal @user.id, json_response["user_id"]
          assert_equal false, json_response["is_reference"]
        end

        test "should update farm" do
          farm = create(:farm, :user_owned, user: @user, name: "元の名前")

          patch api_v1_masters_farm_path(farm),
                params: {
                  farm: {
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

        test "should destroy farm" do
          farm = create(:farm, :user_owned, user: @user)

          assert_difference("@user.farms.where(is_reference: false).count", -1) do
            delete api_v1_masters_farm_path(farm),
                   headers: {
                     "Accept" => "application/json",
                     "X-API-Key" => @api_key
                   }
          end

          assert_response :success
          json_response = JSON.parse(response.body)
          assert json_response.key?('undo_token')
          assert json_response.key?('toast_message')
          assert json_response.key?('undo_path')
        end

        test "cannot access other user's farm" do
          farm = create(:farm, :user_owned, user: create(:user))

          get api_v1_masters_farm_path(farm),
              headers: {
                "Accept" => "application/json",
                "X-API-Key" => @api_key
              }
          assert_response :forbidden

          patch api_v1_masters_farm_path(farm),
                params: {
                  farm: { name: "更新されない" }
                },
                headers: {
                  "Accept" => "application/json",
                  "X-API-Key" => @api_key
                }
          assert_response :forbidden

          delete api_v1_masters_farm_path(farm),
                 headers: {
                   "Accept" => "application/json",
                   "X-API-Key" => @api_key
                 }
          assert_response :forbidden
        end
      end
    end
  end
end
