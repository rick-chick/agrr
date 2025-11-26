# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    module Masters
      module Crops
        class PestsControllerTest < ActionDispatch::IntegrationTest
          setup do
            @user = create(:user)
            @user.generate_api_key!
            @api_key = @user.api_key
            @crop = create(:crop, :user_owned, user: @user)
          end

          test "should get index" do
            pest1 = create(:pest, :user_owned, user: @user)
            pest2 = create(:pest, :reference)
            @crop.pests << [pest1, pest2]
            # 他のユーザーの害虫は含まれない
            other_user = create(:user)
            other_pest = create(:pest, :user_owned, user: other_user)
            @crop.pests << other_pest

            get api_v1_masters_crop_pests_path(@crop),
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
            assert_not_includes pest_ids, other_pest.id
          end

          test "should not get index for other user's crop" do
            other_user = create(:user)
            other_crop = create(:crop, :user_owned, user: other_user)

            get api_v1_masters_crop_pests_path(other_crop),
                headers: {
                  "Accept" => "application/json",
                  "X-API-Key" => @api_key
                }

            assert_response :not_found
            json_response = JSON.parse(response.body)
            assert_equal "Crop not found", json_response["error"]
          end

          test "should create association" do
            pest = create(:pest, :user_owned, user: @user)

            assert_difference("@crop.pests.count", 1) do
              post api_v1_masters_crop_pests_path(@crop),
                   params: {
                     pest_id: pest.id
                   },
                   headers: {
                     "Accept" => "application/json",
                     "X-API-Key" => @api_key
                   }
            end

            assert_response :created
            json_response = JSON.parse(response.body)
            assert_equal "Pest associated successfully", json_response["message"]
            assert_equal @crop.id, json_response["crop_id"]
            assert_equal pest.id, json_response["pest_id"]
          end

          test "should create association with reference pest" do
            reference_pest = create(:pest, :reference)

            assert_difference("@crop.pests.count", 1) do
              post api_v1_masters_crop_pests_path(@crop),
                   params: {
                     pest_id: reference_pest.id
                   },
                   headers: {
                     "Accept" => "application/json",
                     "X-API-Key" => @api_key
                   }
            end

            assert_response :created
          end

          test "should not create association without pest_id" do
            assert_no_difference("@crop.pests.count") do
              post api_v1_masters_crop_pests_path(@crop),
                   params: {},
                   headers: {
                     "Accept" => "application/json",
                     "X-API-Key" => @api_key
                   }
            end

            assert_response :unprocessable_entity
            json_response = JSON.parse(response.body)
            assert_equal "pest_id is required", json_response["error"]
          end

          test "should not create association with non-existent pest" do
            assert_no_difference("@crop.pests.count") do
              post api_v1_masters_crop_pests_path(@crop),
                   params: {
                     pest_id: 99999
                   },
                   headers: {
                     "Accept" => "application/json",
                     "X-API-Key" => @api_key
                   }
            end

            assert_response :not_found
            json_response = JSON.parse(response.body)
            assert_equal "Pest not found", json_response["error"]
          end

          test "should not create association with other user's pest" do
            other_user = create(:user)
            other_pest = create(:pest, :user_owned, user: other_user)

            assert_no_difference("@crop.pests.count") do
              post api_v1_masters_crop_pests_path(@crop),
                   params: {
                     pest_id: other_pest.id
                   },
                   headers: {
                     "Accept" => "application/json",
                     "X-API-Key" => @api_key
                   }
            end

            assert_response :forbidden
            json_response = JSON.parse(response.body)
            assert_equal "You do not have permission to associate this pest", json_response["error"]
          end

          test "should not create duplicate association" do
            pest = create(:pest, :user_owned, user: @user)
            @crop.pests << pest

            assert_no_difference("@crop.pests.count") do
              post api_v1_masters_crop_pests_path(@crop),
                   params: {
                     pest_id: pest.id
                   },
                   headers: {
                     "Accept" => "application/json",
                     "X-API-Key" => @api_key
                   }
            end

            assert_response :unprocessable_entity
            json_response = JSON.parse(response.body)
            assert_equal "Pest is already associated with this crop", json_response["error"]
          end

          test "should destroy association" do
            pest = create(:pest, :user_owned, user: @user)
            @crop.pests << pest

            assert_difference("@crop.pests.count", -1) do
              delete api_v1_masters_crop_pest_path(@crop, pest),
                     headers: {
                       "Accept" => "application/json",
                       "X-API-Key" => @api_key
                     }
            end

            assert_response :no_content
          end

          test "should not destroy non-existent association" do
            pest = create(:pest, :user_owned, user: @user)
            # 関連付けていない

            assert_no_difference("@crop.pests.count") do
              delete api_v1_masters_crop_pest_path(@crop, pest),
                     headers: {
                       "Accept" => "application/json",
                       "X-API-Key" => @api_key
                     }
            end

            assert_response :not_found
            json_response = JSON.parse(response.body)
            assert_equal "Pest is not associated with this crop", json_response["error"]
          end

          test "should not destroy association for other user's crop" do
            other_user = create(:user)
            other_crop = create(:crop, :user_owned, user: other_user)
            pest = create(:pest, :user_owned, user: @user)
            other_crop.pests << pest

            assert_no_difference("CropPest.count") do
              delete api_v1_masters_crop_pest_path(other_crop, pest),
                     headers: {
                       "Accept" => "application/json",
                       "X-API-Key" => @api_key
                     }
            end

            assert_response :not_found
          end
        end
      end
    end
  end
end
