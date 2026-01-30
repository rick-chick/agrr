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

        test "includes Fertilize Views" do
          assert_includes Api::V1::Masters::FertilizesController.included_modules, Views::Api::Fertilize::FertilizeListView
          assert_includes Api::V1::Masters::FertilizesController.included_modules, Views::Api::Fertilize::FertilizeDetailView
          assert_includes Api::V1::Masters::FertilizesController.included_modules, Views::Api::Fertilize::FertilizeCreateView
          assert_includes Api::V1::Masters::FertilizesController.included_modules, Views::Api::Fertilize::FertilizeUpdateView
          assert_includes Api::V1::Masters::FertilizesController.included_modules, Views::Api::Fertilize::FertilizeDeleteView
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

        # name が blank のレコードがあると Entity 変換で ArgumentError になるため、
        # Gateway は name が present なレコードのみ list に含める。このテストで 422 を防ぐことを検証する。
        test "should return success and exclude fertilizes with blank name" do
          fertilize_with_name = create(:fertilize, :user_owned, user: @user, name: "Valid")
          fertilize_blank_name = create(:fertilize, :user_owned, user: @user, name: "Temporary")
          fertilize_blank_name.update_column(:name, "")

          get api_v1_masters_fertilizes_path,
              headers: {
                "Accept" => "application/json",
                "X-API-Key" => @api_key
              }

          assert_response :success
          json_response = JSON.parse(response.body)
          ids = json_response.map { |f| f["id"] }
          assert_includes ids, fertilize_with_name.id
          assert_not_includes ids, fertilize_blank_name.id
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

        test "should not show other user's fertilize" do
          other_user = create(:user)
          other_fertilize = create(:fertilize, :user_owned, user: other_user)

          get api_v1_masters_fertilize_path(other_fertilize),
              headers: {
                "Accept" => "application/json",
                "X-API-Key" => @api_key
              }

          assert_response :forbidden
          json_response = JSON.parse(response.body)
          assert_equal I18n.t("fertilizes.flash.no_permission"), json_response["error"]
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
                as: :json,
                headers: {
                  "Accept" => "application/json",
                  "X-API-Key" => @api_key
                }

          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal "更新された名前", json_response["name"]
        end

        test "should not update other user's fertilize" do
          other_user = create(:user)
          other_fertilize = create(:fertilize, :user_owned, user: other_user, name: "他のユーザーの肥料")

          patch api_v1_masters_fertilize_path(other_fertilize),
                params: {
                  fertilize: {
                    name: "変更しようとした名前"
                  }
                },
                headers: {
                  "Accept" => "application/json",
                  "X-API-Key" => @api_key
                }

          assert_response :forbidden

          other_fertilize.reload
          assert_equal "他のユーザーの肥料", other_fertilize.name
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
          assert json_response.key?('undo_token')
          assert json_response.key?('toast_message')
          assert json_response.key?('undo_path')
        end

        test "should not destroy other user's fertilize" do
          other_user = create(:user)
          other_fertilize = create(:fertilize, :user_owned, user: other_user)

          assert_no_difference("Fertilize.count") do
            delete api_v1_masters_fertilize_path(other_fertilize),
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
