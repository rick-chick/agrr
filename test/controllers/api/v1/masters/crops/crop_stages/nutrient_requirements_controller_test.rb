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
              requirement = create(:nutrient_requirement, crop_stage: @crop_stage,
                                daily_uptake_n: 1.5, daily_uptake_p: 0.3, daily_uptake_k: 1.2, region: "関東")

              get api_v1_masters_crop_crop_stage_nutrient_requirement_path(@crop, @crop_stage),
                  headers: {
                    "Accept" => "application/json",
                    "X-API-Key" => @api_key
                  }

              assert_response :success
              json_response = JSON.parse(response.body)
              assert_equal requirement.id, json_response["id"]
              assert_equal 1.5, json_response["daily_uptake_n"]
              assert_equal 0.3, json_response["daily_uptake_p"]
              assert_equal 1.2, json_response["daily_uptake_k"]
              assert_equal "関東", json_response["region"]
            end

            test "should return not found when nutrient_requirement does not exist" do
              get api_v1_masters_crop_crop_stage_nutrient_requirement_path(@crop, @crop_stage),
                  headers: {
                    "Accept" => "application/json",
                    "X-API-Key" => @api_key
                  }

              assert_response :not_found
              json_response = JSON.parse(response.body)
              assert_equal "NutrientRequirement not found", json_response["error"]
            end

            test "should not show nutrient_requirement for other user's crop" do
              other_user = create(:user)
              other_crop = create(:crop, :user_owned, user: other_user)
              other_crop_stage = create(:crop_stage, crop: other_crop)
              create(:nutrient_requirement, crop_stage: other_crop_stage)

              get api_v1_masters_crop_crop_stage_nutrient_requirement_path(other_crop, other_crop_stage),
                  headers: {
                    "Accept" => "application/json",
                    "X-API-Key" => @api_key
                  }

              assert_response :not_found
            end

            test "should create nutrient_requirement" do
              assert_difference("NutrientRequirement.count", 1) do
                post api_v1_masters_crop_crop_stage_nutrient_requirement_path(@crop, @crop_stage),
                     params: {
                       nutrient_requirement: {
                         daily_uptake_n: 2.0,
                         daily_uptake_p: 0.4,
                         daily_uptake_k: 1.8,
                         region: "北海道"
                       }
                     },
                     headers: {
                       "Accept" => "application/json",
                       "X-API-Key" => @api_key
                     }
              end

              assert_response :created
              json_response = JSON.parse(response.body)
              assert_equal 2.0, json_response["daily_uptake_n"]
              assert_equal 0.4, json_response["daily_uptake_p"]
              assert_equal 1.8, json_response["daily_uptake_k"]
              assert_equal "北海道", json_response["region"]
              assert_equal @crop_stage.id, json_response["crop_stage_id"]
            end

            test "should not create nutrient_requirement if already exists" do
              create(:nutrient_requirement, crop_stage: @crop_stage)

              assert_no_difference("NutrientRequirement.count") do
                post api_v1_masters_crop_crop_stage_nutrient_requirement_path(@crop, @crop_stage),
                     params: {
                       nutrient_requirement: {
                         daily_uptake_n: 2.0
                       }
                     },
                     headers: {
                       "Accept" => "application/json",
                       "X-API-Key" => @api_key
                     }
              end

              assert_response :unprocessable_entity
              json_response = JSON.parse(response.body)
              assert_equal "NutrientRequirement already exists", json_response["error"]
            end

            test "should not create nutrient_requirement with invalid params" do
              assert_no_difference("NutrientRequirement.count") do
                post api_v1_masters_crop_crop_stage_nutrient_requirement_path(@crop, @crop_stage),
                     params: {
                       nutrient_requirement: {
                         daily_uptake_n: "invalid"
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

            test "should update nutrient_requirement" do
              requirement = create(:nutrient_requirement, crop_stage: @crop_stage,
                                daily_uptake_n: 1.5, daily_uptake_p: 0.3, daily_uptake_k: 1.2, region: "関東")

              patch api_v1_masters_crop_crop_stage_nutrient_requirement_path(@crop, @crop_stage),
                    params: {
                      nutrient_requirement: {
                        daily_uptake_n: 2.5,
                        daily_uptake_p: 0.5,
                        daily_uptake_k: 2.0,
                        region: "九州"
                      }
                    },
                    headers: {
                      "Accept" => "application/json",
                      "X-API-Key" => @api_key
                    }

              assert_response :success
              json_response = JSON.parse(response.body)
              assert_equal 2.5, json_response["daily_uptake_n"]
              assert_equal 0.5, json_response["daily_uptake_p"]
              assert_equal 2.0, json_response["daily_uptake_k"]
              assert_equal "九州", json_response["region"]

              requirement.reload
              assert_equal 2.5, requirement.daily_uptake_n
              assert_equal 0.5, requirement.daily_uptake_p
              assert_equal 2.0, requirement.daily_uptake_k
              assert_equal "九州", requirement.region
            end

            test "should not update nutrient_requirement if not found" do
              patch api_v1_masters_crop_crop_stage_nutrient_requirement_path(@crop, @crop_stage),
                    params: {
                      nutrient_requirement: {
                        daily_uptake_n: 2.5
                      }
                    },
                    headers: {
                      "Accept" => "application/json",
                      "X-API-Key" => @api_key
                    }

              assert_response :not_found
              json_response = JSON.parse(response.body)
              assert_equal "NutrientRequirement not found", json_response["error"]
            end

            test "should not update nutrient_requirement for other user's crop" do
              other_user = create(:user)
              other_crop = create(:crop, :user_owned, user: other_user)
              other_crop_stage = create(:crop_stage, crop: other_crop)
              requirement = create(:nutrient_requirement, crop_stage: other_crop_stage,
                                daily_uptake_n: 1.5)

              patch api_v1_masters_crop_crop_stage_nutrient_requirement_path(other_crop, other_crop_stage),
                    params: {
                      nutrient_requirement: {
                        daily_uptake_n: 2.5
                      }
                    },
                    headers: {
                      "Accept" => "application/json",
                      "X-API-Key" => @api_key
                    }

              assert_response :not_found

              requirement.reload
              assert_equal 1.5, requirement.daily_uptake_n
            end

            test "should destroy nutrient_requirement" do
              requirement = create(:nutrient_requirement, crop_stage: @crop_stage)

              assert_difference("NutrientRequirement.count", -1) do
                delete api_v1_masters_crop_crop_stage_nutrient_requirement_path(@crop, @crop_stage),
                       headers: {
                         "Accept" => "application/json",
                         "X-API-Key" => @api_key
                       }
              end

              assert_response :no_content
            end

            test "should not destroy nutrient_requirement if not found" do
              delete api_v1_masters_crop_crop_stage_nutrient_requirement_path(@crop, @crop_stage),
                     headers: {
                       "Accept" => "application/json",
                       "X-API-Key" => @api_key
                     }

              assert_response :not_found
              json_response = JSON.parse(response.body)
              assert_equal "NutrientRequirement not found", json_response["error"]
            end

            test "should not destroy nutrient_requirement for other user's crop" do
              other_user = create(:user)
              other_crop = create(:crop, :user_owned, user: other_user)
              other_crop_stage = create(:crop_stage, crop: other_crop)
              create(:nutrient_requirement, crop_stage: other_crop_stage)

              assert_no_difference("NutrientRequirement.count") do
                delete api_v1_masters_crop_crop_stage_nutrient_requirement_path(other_crop, other_crop_stage),
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