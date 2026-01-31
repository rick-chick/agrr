# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    module Masters
      module Crops
        module CropStages
          class SunshineRequirementsControllerTest < ActionDispatch::IntegrationTest
            setup do
              @user = create(:user)
              @user.generate_api_key!
              @api_key = @user.api_key
              @crop = create(:crop, :user_owned, user: @user)
              @crop_stage = create(:crop_stage, crop: @crop)
            end

            test "should show sunshine_requirement" do
              requirement = create(:sunshine_requirement, crop_stage: @crop_stage,
                                minimum_sunshine_hours: 4.0, target_sunshine_hours: 8.0)

              get api_v1_masters_crop_crop_stage_sunshine_requirement_path(@crop, @crop_stage),
                  headers: {
                    "Accept" => "application/json",
                    "X-API-Key" => @api_key
                  }

              assert_response :success
              json_response = JSON.parse(response.body)
              assert_equal requirement.id, json_response["id"]
              assert_equal 4.0, json_response["minimum_sunshine_hours"]
              assert_equal 8.0, json_response["target_sunshine_hours"]
            end

            test "should return not found when sunshine_requirement does not exist" do
              get api_v1_masters_crop_crop_stage_sunshine_requirement_path(@crop, @crop_stage),
                  headers: {
                    "Accept" => "application/json",
                    "X-API-Key" => @api_key
                  }

              assert_response :not_found
              json_response = JSON.parse(response.body)
              assert_equal "SunshineRequirement not found", json_response["error"]
            end

            test "should not show sunshine_requirement for other user's crop" do
              other_user = create(:user)
              other_crop = create(:crop, :user_owned, user: other_user)
              other_crop_stage = create(:crop_stage, crop: other_crop)
              create(:sunshine_requirement, crop_stage: other_crop_stage)

              get api_v1_masters_crop_crop_stage_sunshine_requirement_path(other_crop, other_crop_stage),
                  headers: {
                    "Accept" => "application/json",
                    "X-API-Key" => @api_key
                  }

              assert_response :not_found
            end

            test "should create sunshine_requirement" do
              assert_difference("SunshineRequirement.count", 1) do
                post api_v1_masters_crop_crop_stage_sunshine_requirement_path(@crop, @crop_stage),
                     params: {
                       sunshine_requirement: {
                         minimum_sunshine_hours: 5.0,
                         target_sunshine_hours: 9.0
                       }
                     },
                     headers: {
                       "Accept" => "application/json",
                       "X-API-Key" => @api_key
                     }
              end

              assert_response :created
              json_response = JSON.parse(response.body)
              assert_equal 5.0, json_response["minimum_sunshine_hours"]
              assert_equal 9.0, json_response["target_sunshine_hours"]
              assert_equal @crop_stage.id, json_response["crop_stage_id"]
            end

            test "should not create sunshine_requirement if already exists" do
              create(:sunshine_requirement, crop_stage: @crop_stage)

              assert_no_difference("SunshineRequirement.count") do
                post api_v1_masters_crop_crop_stage_sunshine_requirement_path(@crop, @crop_stage),
                     params: {
                       sunshine_requirement: {
                         minimum_sunshine_hours: 5.0
                       }
                     },
                     headers: {
                       "Accept" => "application/json",
                       "X-API-Key" => @api_key
                     }
              end

              assert_response :unprocessable_entity
              json_response = JSON.parse(response.body)
              assert_equal "SunshineRequirement already exists", json_response["error"]
            end

            test "should not create sunshine_requirement with invalid params" do
              assert_no_difference("SunshineRequirement.count") do
                post api_v1_masters_crop_crop_stage_sunshine_requirement_path(@crop, @crop_stage),
                     params: {
                       sunshine_requirement: {
                         minimum_sunshine_hours: "invalid"
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

            test "should update sunshine_requirement" do
              requirement = create(:sunshine_requirement, crop_stage: @crop_stage,
                                minimum_sunshine_hours: 4.0, target_sunshine_hours: 8.0)

              patch api_v1_masters_crop_crop_stage_sunshine_requirement_path(@crop, @crop_stage),
                    params: {
                      sunshine_requirement: {
                        minimum_sunshine_hours: 6.0,
                        target_sunshine_hours: 10.0
                      }
                    },
                    headers: {
                      "Accept" => "application/json",
                      "X-API-Key" => @api_key
                    }

              assert_response :success
              json_response = JSON.parse(response.body)
              assert_equal 6.0, json_response["minimum_sunshine_hours"]
              assert_equal 10.0, json_response["target_sunshine_hours"]

              requirement.reload
              assert_equal 6.0, requirement.minimum_sunshine_hours
              assert_equal 10.0, requirement.target_sunshine_hours
            end

            test "should not update sunshine_requirement if not found" do
              patch api_v1_masters_crop_crop_stage_sunshine_requirement_path(@crop, @crop_stage),
                    params: {
                      sunshine_requirement: {
                        minimum_sunshine_hours: 6.0
                      }
                    },
                    headers: {
                      "Accept" => "application/json",
                      "X-API-Key" => @api_key
                    }

              assert_response :not_found
              json_response = JSON.parse(response.body)
              assert_equal "SunshineRequirement not found", json_response["error"]
            end

            test "should not update sunshine_requirement for other user's crop" do
              other_user = create(:user)
              other_crop = create(:crop, :user_owned, user: other_user)
              other_crop_stage = create(:crop_stage, crop: other_crop)
              requirement = create(:sunshine_requirement, crop_stage: other_crop_stage,
                                minimum_sunshine_hours: 4.0)

              patch api_v1_masters_crop_crop_stage_sunshine_requirement_path(other_crop, other_crop_stage),
                    params: {
                      sunshine_requirement: {
                        minimum_sunshine_hours: 6.0
                      }
                    },
                    headers: {
                      "Accept" => "application/json",
                      "X-API-Key" => @api_key
                    }

              assert_response :not_found

              requirement.reload
              assert_equal 4.0, requirement.minimum_sunshine_hours
            end

            test "should destroy sunshine_requirement" do
              requirement = create(:sunshine_requirement, crop_stage: @crop_stage)

              assert_difference("SunshineRequirement.count", -1) do
                delete api_v1_masters_crop_crop_stage_sunshine_requirement_path(@crop, @crop_stage),
                       headers: {
                         "Accept" => "application/json",
                         "X-API-Key" => @api_key
                       }
              end

              assert_response :no_content
            end

            test "should not destroy sunshine_requirement if not found" do
              delete api_v1_masters_crop_crop_stage_sunshine_requirement_path(@crop, @crop_stage),
                     headers: {
                       "Accept" => "application/json",
                       "X-API-Key" => @api_key
                     }

              assert_response :not_found
              json_response = JSON.parse(response.body)
              assert_equal "SunshineRequirement not found", json_response["error"]
            end

            test "should not destroy sunshine_requirement for other user's crop" do
              other_user = create(:user)
              other_crop = create(:crop, :user_owned, user: other_user)
              other_crop_stage = create(:crop_stage, crop: other_crop)
              create(:sunshine_requirement, crop_stage: other_crop_stage)

              assert_no_difference("SunshineRequirement.count") do
                delete api_v1_masters_crop_crop_stage_sunshine_requirement_path(other_crop, other_crop_stage),
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
end