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
              requirement = create(:sunshine_requirement, crop_stage: @crop_stage)

              get api_v1_masters_crop_crop_stage_sunshine_requirement_path(@crop, @crop_stage),
                  headers: {
                    "Accept" => "application/json",
                    "X-API-Key" => @api_key
                  }

              assert_response :success
              json_response = JSON.parse(response.body)
              assert_equal requirement.id, json_response["id"]
            end

            test "should create sunshine_requirement" do
              assert_difference("SunshineRequirement.count", 1) do
                post api_v1_masters_crop_crop_stage_sunshine_requirement_path(@crop, @crop_stage),
                     params: {
                       sunshine_requirement: {
                         minimum_sunshine_hours: 4.0,
                         target_sunshine_hours: 8.0
                       }
                     },
                     headers: {
                       "Accept" => "application/json",
                       "X-API-Key" => @api_key
                     }
              end

              assert_response :created
            end

            test "should update sunshine_requirement" do
              requirement = create(:sunshine_requirement, crop_stage: @crop_stage, minimum_sunshine_hours: 4.0)

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

              assert_response :success
              requirement.reload
              assert_equal 6.0, requirement.minimum_sunshine_hours
            end

            test "should destroy sunshine_requirement" do
              create(:sunshine_requirement, crop_stage: @crop_stage)

              assert_difference("SunshineRequirement.count", -1) do
                delete api_v1_masters_crop_crop_stage_sunshine_requirement_path(@crop, @crop_stage),
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
