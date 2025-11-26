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
              requirement = create(:thermal_requirement, crop_stage: @crop_stage)

              get api_v1_masters_crop_crop_stage_thermal_requirement_path(@crop, @crop_stage),
                  headers: {
                    "Accept" => "application/json",
                    "X-API-Key" => @api_key
                  }

              assert_response :success
              json_response = JSON.parse(response.body)
              assert_equal requirement.id, json_response["id"]
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
            end

            test "should update thermal_requirement" do
              requirement = create(:thermal_requirement, crop_stage: @crop_stage, required_gdd: 200.0)

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
              requirement.reload
              assert_equal 250.0, requirement.required_gdd
            end

            test "should destroy thermal_requirement" do
              create(:thermal_requirement, crop_stage: @crop_stage)

              assert_difference("ThermalRequirement.count", -1) do
                delete api_v1_masters_crop_crop_stage_thermal_requirement_path(@crop, @crop_stage),
                       headers: {
                         "Accept" => "application/json",
                         "X-API-Key" => @api_key
                       }
              end

              assert_response :no_content
            end
          end
        end
      end
    end
  end
end
