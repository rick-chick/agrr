# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    module Masters
      module Crops
        class CropStagesControllerTest < ActionDispatch::IntegrationTest
          setup do
            @user = create(:user)
            @user.generate_api_key!
            @api_key = @user.api_key
            @crop = create(:crop, :user_owned, user: @user)
          end

          test "should get index" do
            stage1 = create(:crop_stage, crop: @crop, name: "発芽期", order: 1)
            stage2 = create(:crop_stage, crop: @crop, name: "栄養成長期", order: 2)

            get api_v1_masters_crop_crop_stages_path(@crop),
                headers: {
                  "Accept" => "application/json",
                  "X-API-Key" => @api_key
                }

            assert_response :success
            json_response = JSON.parse(response.body)
            assert_equal 2, json_response.length
            stage_ids = json_response.map { |s| s["id"] }
            assert_includes stage_ids, stage1.id
            assert_includes stage_ids, stage2.id
            # order順に並んでいることを確認
            assert_equal stage1.id, json_response[0]["id"]
            assert_equal stage2.id, json_response[1]["id"]
          end

          test "should not get index for other user's crop" do
            other_user = create(:user)
            other_crop = create(:crop, :user_owned, user: other_user)

            get api_v1_masters_crop_crop_stages_path(other_crop),
                headers: {
                  "Accept" => "application/json",
                  "X-API-Key" => @api_key
                }

            assert_response :not_found
            json_response = JSON.parse(response.body)
            assert_equal "Crop not found", json_response["error"]
          end

          test "should show crop_stage" do
            stage = create(:crop_stage, crop: @crop, name: "発芽期", order: 1)

            get api_v1_masters_crop_crop_stage_path(@crop, stage),
                headers: {
                  "Accept" => "application/json",
                  "X-API-Key" => @api_key
                }

            assert_response :success
            json_response = JSON.parse(response.body)
            assert_equal stage.id, json_response["id"]
            assert_equal "発芽期", json_response["name"]
            assert_equal 1, json_response["order"]
          end

          test "should not show crop_stage for other user's crop" do
            other_user = create(:user)
            other_crop = create(:crop, :user_owned, user: other_user)
            stage = create(:crop_stage, crop: other_crop)

            get api_v1_masters_crop_crop_stage_path(other_crop, stage),
                headers: {
                  "Accept" => "application/json",
                  "X-API-Key" => @api_key
                }

            assert_response :not_found
          end

          test "should create crop_stage" do
            assert_difference("@crop.crop_stages.count", 1) do
              post api_v1_masters_crop_crop_stages_path(@crop),
                   params: {
                     crop_stage: {
                       name: "開花期",
                       order: 3
                     }
                   },
                   headers: {
                     "Accept" => "application/json",
                     "X-API-Key" => @api_key
                   }
            end

            assert_response :created
            json_response = JSON.parse(response.body)
            assert_equal "開花期", json_response["name"]
            assert_equal 3, json_response["order"]
            assert_equal @crop.id, json_response["crop_id"]
          end

          test "should not create crop_stage with invalid params" do
            assert_no_difference("@crop.crop_stages.count") do
              post api_v1_masters_crop_crop_stages_path(@crop),
                   params: {
                     crop_stage: {
                       name: nil,
                       order: 1
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

          test "should update crop_stage" do
            stage = create(:crop_stage, crop: @crop, name: "元の名前", order: 1)

            patch api_v1_masters_crop_crop_stage_path(@crop, stage),
                  params: {
                    crop_stage: {
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

            stage.reload
            assert_equal "更新された名前", stage.name
          end

          test "should not update crop_stage for other user's crop" do
            other_user = create(:user)
            other_crop = create(:crop, :user_owned, user: other_user)
            stage = create(:crop_stage, crop: other_crop, name: "元の名前")

            patch api_v1_masters_crop_crop_stage_path(other_crop, stage),
                  params: {
                    crop_stage: {
                      name: "変更しようとした名前"
                    }
                  },
                  headers: {
                    "Accept" => "application/json",
                    "X-API-Key" => @api_key
                  }

            assert_response :not_found

            stage.reload
            assert_equal "元の名前", stage.name
          end

          test "should destroy crop_stage" do
            stage = create(:crop_stage, crop: @crop)

            assert_difference("@crop.crop_stages.count", -1) do
              delete api_v1_masters_crop_crop_stage_path(@crop, stage),
                     headers: {
                       "Accept" => "application/json",
                       "X-API-Key" => @api_key
                     }
            end

            assert_response :no_content
          end

          test "should not destroy crop_stage for other user's crop" do
            other_user = create(:user)
            other_crop = create(:crop, :user_owned, user: other_user)
            stage = create(:crop_stage, crop: other_crop)

            assert_no_difference("CropStage.count") do
              delete api_v1_masters_crop_crop_stage_path(other_crop, stage),
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
