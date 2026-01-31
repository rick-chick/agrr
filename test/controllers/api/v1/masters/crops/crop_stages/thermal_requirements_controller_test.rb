# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    module Masters
      module Crops
        module CropStages
          class ThermalRequirementsControllerTest < ActionDispatch::IntegrationTest
            setup do
              @user = create(:user)
              @user.generate_api_key!
              @api_key = @user.api_key
              @crop = create(:crop, :user_owned, user: @user)
              @crop_stage = create(:crop_stage, crop: @crop)
            end

            test "should show thermal_requirement" do
              requirement = create(:thermal_requirement, crop_stage: @crop_stage,
                                required_gdd: 150.0)

              get api_v1_masters_crop_crop_stage_thermal_requirement_path(@crop, @crop_stage),
                  headers: {
                    "Accept" => "application/json",
                    "X-API-Key" => @api_key
                  }

              assert_response :success
              json_response = JSON.parse(response.body)
              assert_equal requirement.id, json_response["id"]
              assert_equal 150.0, json_response["required_gdd"]
            end

            test "should return not found when thermal_requirement does not exist" do
              get api_v1_masters_crop_crop_stage_thermal_requirement_path(@crop, @crop_stage),
                  headers: {
                    "Accept" => "application/json",
                    "X-API-Key" => @api_key
                  }

              assert_response :not_found
              json_response = JSON.parse(response.body)
              assert_equal "ThermalRequirement not found", json_response["error"]
            end

            test "should not show thermal_requirement for other user's crop" do
              other_user = create(:user)
              other_crop = create(:crop, :user_owned, user: other_user)
              other_crop_stage = create(:crop_stage, crop: other_crop)
              create(:thermal_requirement, crop_stage: other_crop_stage)

              get api_v1_masters_crop_crop_stage_thermal_requirement_path(other_crop, other_crop_stage),
                  headers: {
                    "Accept" => "application/json",
                    "X-API-Key" => @api_key
                  }

              assert_response :not_found
            end

            test "should create thermal_requirement" do
              assert_difference("ThermalRequirement.count", 1) do
                post api_v1_masters_crop_crop_stage_thermal_requirement_path(@crop, @crop_stage),
                     params: {
                       thermal_requirement: {
                         required_gdd: 200.0
                       }
                     },
                     headers: {
                       "Accept" => "application/json",
                       "X-API-Key" => @api_key
                     }
              end

              assert_response :created
              json_response = JSON.parse(response.body)
              assert_equal 200.0, json_response["required_gdd"]
              assert_equal @crop_stage.id, json_response["crop_stage_id"]
            end

            test "should not create thermal_requirement if already exists" do
              create(:thermal_requirement, crop_stage: @crop_stage)

              assert_no_difference("ThermalRequirement.count") do
                post api_v1_masters_crop_crop_stage_thermal_requirement_path(@crop, @crop_stage),
                     params: {
                       thermal_requirement: {
                         required_gdd: 200.0
                       }
                     },
                     headers: {
                       "Accept" => "application/json",
                       "X-API-Key" => @api_key
                     }
              end

              assert_response :unprocessable_entity
              json_response = JSON.parse(response.body)
              assert_equal "ThermalRequirement already exists", json_response["error"]
            end

            test "should not create thermal_requirement with invalid params" do
              assert_no_difference("ThermalRequirement.count") do
                post api_v1_masters_crop_crop_stage_thermal_requirement_path(@crop, @crop_stage),
                     params: {
                       thermal_requirement: {
                         required_gdd: "invalid"
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

            test "should update thermal_requirement" do
              requirement = create(:thermal_requirement, crop_stage: @crop_stage,
                                required_gdd: 150.0)

              patch api_v1_masters_crop_crop_stage_thermal_requirement_path(@crop, @crop_stage),
                    params: {
                      thermal_requirement: {
                        required_gdd: 250.0
                      }
                    },
                    headers: {
                      "Accept" => "application/json",
                      "X-API-Key" => @api_key
                    }

              assert_response :success
              json_response = JSON.parse(response.body)
              assert_equal 250.0, json_response["required_gdd"]

              requirement.reload
              assert_equal 250.0, requirement.required_gdd
            end

            test "should not update thermal_requirement if not found" do
              patch api_v1_masters_crop_crop_stage_thermal_requirement_path(@crop, @crop_stage),
                    params: {
                      thermal_requirement: {
                        required_gdd: 250.0
                      }
                    },
                    headers: {
                      "Accept" => "application/json",
                      "X-API-Key" => @api_key
                    }

              assert_response :not_found
              json_response = JSON.parse(response.body)
              assert_equal "ThermalRequirement not found", json_response["error"]
            end

            test "should not update thermal_requirement for other user's crop" do
              other_user = create(:user)
              other_crop = create(:crop, :user_owned, user: other_user)
              other_crop_stage = create(:crop_stage, crop: other_crop)
              requirement = create(:thermal_requirement, crop_stage: other_crop_stage, required_gdd: 150.0)

              patch api_v1_masters_crop_crop_stage_thermal_requirement_path(other_crop, other_crop_stage),
                    params: {
                      thermal_requirement: {
                        required_gdd: 250.0
                      }
                    },
                    headers: {
                      "Accept" => "application/json",
                      "X-API-Key" => @api_key
                    }

              assert_response :not_found

              requirement.reload
              assert_equal 150.0, requirement.required_gdd
            end

            test "should destroy thermal_requirement" do
              requirement = create(:thermal_requirement, crop_stage: @crop_stage)

              assert_difference("ThermalRequirement.count", -1) do
                delete api_v1_masters_crop_crop_stage_thermal_requirement_path(@crop, @crop_stage),
                       headers: {
                         "Accept" => "application/json",
                         "X-API-Key" => @api_key
                       }
              end

              assert_response :no_content
            end

            test "should not destroy thermal_requirement if not found" do
              delete api_v1_masters_crop_crop_stage_thermal_requirement_path(@crop, @crop_stage),
                     headers: {
                       "Accept" => "application/json",
                       "X-API-Key" => @api_key
                     }

              assert_response :not_found
              json_response = JSON.parse(response.body)
              assert_equal "ThermalRequirement not found", json_response["error"]
            end

            test "should not destroy thermal_requirement for other user's crop" do
              other_user = create(:user)
              other_crop = create(:crop, :user_owned, user: other_user)
              other_crop_stage = create(:crop_stage, crop: other_crop)
              create(:thermal_requirement, crop_stage: other_crop_stage)

              assert_no_difference("ThermalRequirement.count") do
                delete api_v1_masters_crop_crop_stage_thermal_requirement_path(other_crop, other_crop_stage),
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