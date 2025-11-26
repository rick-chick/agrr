# frozen_string_literal: true

require "test_helper"

module Api
  module V1
    module Masters
      module Crops
        module CropStages
          class NutrientRequirementsControllerTest < ActionDispatch::IntegrationTest
            setup do
              @user = create(:user)
              @user.generate_api_key!
              @api_key = @user.api_key
              @crop = create(:crop, :user_owned, user: @user)
              @crop_stage = create(:crop_stage, crop: @crop)
            end

            test "should show nutrient_requirement" do
              requirement = create(:nutrient_requirement, crop_stage: @crop_stage)

              get api_v1_masters_crop_crop_stage_nutrient_requirement_path(@crop, @crop_stage),
                  headers: {
                    "Accept" => "application/json",
                    "X-API-Key" => @api_key
                  }

              assert_response :success
              json_response = JSON.parse(response.body)
              assert_equal requirement.id, json_response["id"]
            end

            test "should create nutrient_requirement" do
              assert_difference("NutrientRequirement.count", 1) do
                post api_v1_masters_crop_crop_stage_nutrient_requirement_path(@crop, @crop_stage),
                     params: {
                       nutrient_requirement: {
                         daily_uptake_n: 0.5,
                         daily_uptake_p: 0.2,
                         daily_uptake_k: 0.8
                       }
                     },
                     headers: {
                       "Accept" => "application/json",
                       "X-API-Key" => @api_key
                     }
              end

              assert_response :created
            end

            test "should update nutrient_requirement" do
              requirement = create(:nutrient_requirement, crop_stage: @crop_stage, daily_uptake_n: 0.5)

              patch api_v1_masters_crop_crop_stage_nutrient_requirement_path(@crop, @crop_stage),
                    params: {
                      nutrient_requirement: {
                        daily_uptake_n: 1.0
                      }
                    },
                    headers: {
                      "Accept" => "application/json",
                      "X-API-Key" => @api_key
                    }

              assert_response :success
              requirement.reload
              assert_equal 1.0, requirement.daily_uptake_n
            end

            test "should destroy nutrient_requirement" do
              create(:nutrient_requirement, crop_stage: @crop_stage)

              assert_difference("NutrientRequirement.count", -1) do
                delete api_v1_masters_crop_crop_stage_nutrient_requirement_path(@crop, @crop_stage),
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
