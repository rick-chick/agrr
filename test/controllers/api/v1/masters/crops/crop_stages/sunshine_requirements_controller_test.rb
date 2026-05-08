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

            MastersCropStageRequirementApiTestCases.define(self, {
              matrix: :smoke,
              resource_label: "sunshine_requirement",
              model: SunshineRequirement,
              factory: :sunshine_requirement,
              param_key: :sunshine_requirement,
              singular_name: "SunshineRequirement",
              path: ->(t, crop, stage) { t.api_v1_masters_crop_crop_stage_sunshine_requirement_path(crop, stage) },
              show_factory_attrs: { minimum_sunshine_hours: 4.0, target_sunshine_hours: 8.0 },
              assert_show_json: proc do |json, requirement|
                assert_equal requirement.id, json["id"]
                assert_equal 4.0, json["minimum_sunshine_hours"]
                assert_equal 8.0, json["target_sunshine_hours"]
              end,
              create_params: { minimum_sunshine_hours: 5.0, target_sunshine_hours: 9.0 },
              assert_create_json: proc do |json|
                assert_equal 5.0, json["minimum_sunshine_hours"]
                assert_equal 9.0, json["target_sunshine_hours"]
                assert_equal @crop_stage.id, json["crop_stage_id"]
              end,
              duplicate_create_params: { minimum_sunshine_hours: 5.0 },
              invalid_param_key: :minimum_sunshine_hours,
              invalid_param_value: "invalid",
              update_factory_attrs: { minimum_sunshine_hours: 4.0, target_sunshine_hours: 8.0 },
              update_params: { minimum_sunshine_hours: 6.0, target_sunshine_hours: 10.0 },
              assert_update_json: proc do |json|
                assert_equal 6.0, json["minimum_sunshine_hours"]
                assert_equal 10.0, json["target_sunshine_hours"]
              end,
              assert_update_persisted: proc do |requirement|
                requirement.reload
                assert_equal 6.0, requirement.minimum_sunshine_hours
                assert_equal 10.0, requirement.target_sunshine_hours
              end,
              other_user_factory_attrs: { minimum_sunshine_hours: 4.0 },
              other_user_update_params: { minimum_sunshine_hours: 6.0 },
              assert_other_user_unchanged: proc do |requirement|
                requirement.reload
                assert_equal 4.0, requirement.minimum_sunshine_hours
              end
            })
          end
        end
      end
    end
  end
end
