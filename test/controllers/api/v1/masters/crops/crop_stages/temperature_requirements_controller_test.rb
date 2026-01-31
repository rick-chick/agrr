# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    module Masters
      module Crops
        module CropStages
          class TemperatureRequirementsControllerTest < ActionDispatch::IntegrationTest
            setup do
              @user = create(:user)
              @user.generate_api_key!
              @api_key = @user.api_key
              @crop = create(:crop, :user_owned, user: @user)
              @crop_stage = create(:crop_stage, crop: @crop)
            end

            test "should show temperature_requirement" do
              requirement = create(:temperature_requirement, crop_stage: @crop_stage,
                                base_temperature: 10.0, optimal_min: 15.0, optimal_max: 25.0)

              get api_v1_masters_crop_crop_stage_temperature_requirement_path(@crop, @crop_stage),
                  headers: {
                    "Accept" => "application/json",
                    "X-API-Key" => @api_key
                  }

              assert_response :success
              json_response = JSON.parse(response.body)
              assert_equal requirement.id, json_response["id"]
              assert_equal 10.0, json_response["base_temperature"]
              assert_equal 15.0, json_response["optimal_min"]
              assert_equal 25.0, json_response["optimal_max"]
            end

            test "should return not found when temperature_requirement does not exist" do
              get api_v1_masters_crop_crop_stage_temperature_requirement_path(@crop, @crop_stage),
                  headers: {
                    "Accept" => "application/json",
                    "X-API-Key" => @api_key
                  }

              assert_response :not_found
              json_response = JSON.parse(response.body)
              assert_equal "TemperatureRequirement not found", json_response["error"]
            end

            test "should not show temperature_requirement for other user's crop" do
              other_user = create(:user)
              other_crop = create(:crop, :user_owned, user: other_user)
              other_crop_stage = create(:crop_stage, crop: other_crop)
              create(:temperature_requirement, crop_stage: other_crop_stage)

              get api_v1_masters_crop_crop_stage_temperature_requirement_path(other_crop, other_crop_stage),
                  headers: {
                    "Accept" => "application/json",
                    "X-API-Key" => @api_key
                  }

              assert_response :not_found
            end

            test "should create temperature_requirement" do
              assert_difference("TemperatureRequirement.count", 1) do
                post api_v1_masters_crop_crop_stage_temperature_requirement_path(@crop, @crop_stage),
                     params: {
                       temperature_requirement: {
                         base_temperature: 12.0,
                         optimal_min: 18.0,
                         optimal_max: 28.0,
                         low_stress_threshold: 5.0,
                         high_stress_threshold: 35.0,
                         frost_threshold: 0.0,
                         sterility_risk_threshold: 40.0,
                         max_temperature: 45.0
                       }
                     },
                     headers: {
                       "Accept" => "application/json",
                       "X-API-Key" => @api_key
                     }
              end

              assert_response :created
              json_response = JSON.parse(response.body)
              assert_equal 12.0, json_response["base_temperature"]
              assert_equal 18.0, json_response["optimal_min"]
              assert_equal 28.0, json_response["optimal_max"]
              assert_equal @crop_stage.id, json_response["crop_stage_id"]
            end

            test "should not create temperature_requirement if already exists" do
              create(:temperature_requirement, crop_stage: @crop_stage)

              assert_no_difference("TemperatureRequirement.count") do
                post api_v1_masters_crop_crop_stage_temperature_requirement_path(@crop, @crop_stage),
                     params: {
                       temperature_requirement: {
                         base_temperature: 12.0
                       }
                     },
                     headers: {
                       "Accept" => "application/json",
                       "X-API-Key" => @api_key
                     }
              end

              assert_response :unprocessable_entity
              json_response = JSON.parse(response.body)
              assert_equal "TemperatureRequirement already exists", json_response["error"]
            end

            test "should not create temperature_requirement with invalid params" do
              assert_no_difference("TemperatureRequirement.count") do
                post api_v1_masters_crop_crop_stage_temperature_requirement_path(@crop, @crop_stage),
                     params: {
                       temperature_requirement: {
                         base_temperature: "invalid"
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

            test "should update temperature_requirement" do
              requirement = create(:temperature_requirement, crop_stage: @crop_stage,
                                base_temperature: 10.0, optimal_min: 15.0)

              patch api_v1_masters_crop_crop_stage_temperature_requirement_path(@crop, @crop_stage),
                    params: {
                      temperature_requirement: {
                        base_temperature: 12.0,
                        optimal_min: 18.0
                      }
                    },
                    headers: {
                      "Accept" => "application/json",
                      "X-API-Key" => @api_key
                    }

              assert_response :success
              json_response = JSON.parse(response.body)
              assert_equal 12.0, json_response["base_temperature"]
              assert_equal 18.0, json_response["optimal_min"]

              requirement.reload
              assert_equal 12.0, requirement.base_temperature
              assert_equal 18.0, requirement.optimal_min
            end

            test "should not update temperature_requirement if not found" do
              patch api_v1_masters_crop_crop_stage_temperature_requirement_path(@crop, @crop_stage),
                    params: {
                      temperature_requirement: {
                        base_temperature: 12.0
                      }
                    },
                    headers: {
                      "Accept" => "application/json",
                      "X-API-Key" => @api_key
                    }

              assert_response :not_found
              json_response = JSON.parse(response.body)
              assert_equal "TemperatureRequirement not found", json_response["error"]
            end

            test "should not update temperature_requirement for other user's crop" do
              other_user = create(:user)
              other_crop = create(:crop, :user_owned, user: other_user)
              other_crop_stage = create(:crop_stage, crop: other_crop)
              requirement = create(:temperature_requirement, crop_stage: other_crop_stage, base_temperature: 10.0)

              patch api_v1_masters_crop_crop_stage_temperature_requirement_path(other_crop, other_crop_stage),
                    params: {
                      temperature_requirement: {
                        base_temperature: 12.0
                      }
                    },
                    headers: {
                      "Accept" => "application/json",
                      "X-API-Key" => @api_key
                    }

              assert_response :not_found

              requirement.reload
              assert_equal 10.0, requirement.base_temperature
            end

            test "should destroy temperature_requirement" do
              requirement = create(:temperature_requirement, crop_stage: @crop_stage)

              assert_difference("TemperatureRequirement.count", -1) do
                delete api_v1_masters_crop_crop_stage_temperature_requirement_path(@crop, @crop_stage),
                       headers: {
                         "Accept" => "application/json",
                         "X-API-Key" => @api_key
                       }
              end

              assert_response :no_content
            end

            test "should not destroy temperature_requirement if not found" do
              delete api_v1_masters_crop_crop_stage_temperature_requirement_path(@crop, @crop_stage),
                     headers: {
                       "Accept" => "application/json",
                       "X-API-Key" => @api_key
                     }

              assert_response :not_found
              json_response = JSON.parse(response.body)
              assert_equal "TemperatureRequirement not found", json_response["error"]
            end

            test "should not destroy temperature_requirement for other user's crop" do
              other_user = create(:user)
              other_crop = create(:crop, :user_owned, user: other_user)
              other_crop_stage = create(:crop_stage, crop: other_crop)
              create(:temperature_requirement, crop_stage: other_crop_stage)

              assert_no_difference("TemperatureRequirement.count") do
                delete api_v1_masters_crop_crop_stage_temperature_requirement_path(other_crop, other_crop_stage),
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