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
              requirement = create(:temperature_requirement, crop_stage: @crop_stage)

              get api_v1_masters_crop_crop_stage_temperature_requirement_path(@crop, @crop_stage),
                  headers: {
                    "Accept" => "application/json",
                    "X-API-Key" => @api_key
                  }

              assert_response :success
              json_response = JSON.parse(response.body)
              assert_equal requirement.id, json_response["id"]
            end

            test "should return 404 when temperature_requirement not found" do
              get api_v1_masters_crop_crop_stage_temperature_requirement_path(@crop, @crop_stage),
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
                         base_temperature: 10.0,
                         optimal_min: 15.0,
                         optimal_max: 25.0
                       }
                     },
                     headers: {
                       "Accept" => "application/json",
                       "X-API-Key" => @api_key
                     }
              end

              assert_response :created
              json_response = JSON.parse(response.body)
              assert_equal 10.0, json_response["base_temperature"]
            end

            test "should not create duplicate temperature_requirement" do
              create(:temperature_requirement, crop_stage: @crop_stage)

              assert_no_difference("TemperatureRequirement.count") do
                post api_v1_masters_crop_crop_stage_temperature_requirement_path(@crop, @crop_stage),
                     params: {
                       temperature_requirement: {
                         base_temperature: 10.0
                       }
                     },
                     headers: {
                       "Accept" => "application/json",
                       "X-API-Key" => @api_key
                     }
              end

              assert_response :unprocessable_entity
            end

            test "should update temperature_requirement" do
              requirement = create(:temperature_requirement, crop_stage: @crop_stage, base_temperature: 10.0)

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

              assert_response :success
              json_response = JSON.parse(response.body)
              assert_equal 12.0, json_response["base_temperature"]

              requirement.reload
              assert_equal 12.0, requirement.base_temperature
            end

            test "should destroy temperature_requirement" do
              create(:temperature_requirement, crop_stage: @crop_stage)

              assert_difference("TemperatureRequirement.count", -1) do
                delete api_v1_masters_crop_crop_stage_temperature_requirement_path(@crop, @crop_stage),
                       headers: {
                         "Accept" => "application/json",
                         "X-API-Key" => @api_key
                       }
              end

              assert_response :no_content
            end

            test "should not access other user's crop" do
              other_user = create(:user)
              other_crop = create(:crop, :user_owned, user: other_user)
              other_stage = create(:crop_stage, crop: other_crop)

              get api_v1_masters_crop_crop_stage_temperature_requirement_path(other_crop, other_stage),
                  headers: {
                    "Accept" => "application/json",
                    "X-API-Key" => @api_key
                  }

              assert_response :not_found
            end
          end
        end
      end
    end
  end
end
