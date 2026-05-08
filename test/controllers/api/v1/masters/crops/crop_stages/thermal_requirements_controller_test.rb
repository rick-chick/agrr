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

            MastersCropStageRequirementApiTestCases.define(self, {
              resource_label: "thermal_requirement",
              model: ThermalRequirement,
              factory: :thermal_requirement,
              param_key: :thermal_requirement,
              singular_name: "ThermalRequirement",
              path: ->(t, crop, stage) { t.api_v1_masters_crop_crop_stage_thermal_requirement_path(crop, stage) },
              show_factory_attrs: { required_gdd: 150.0 },
              assert_show_json: proc do |json, requirement|
                assert_equal requirement.id, json["id"]
                assert_equal 150.0, json["required_gdd"]
              end,
              create_params: { required_gdd: 200.0 },
              assert_create_json: proc do |json|
                assert_equal 200.0, json["required_gdd"]
                assert_equal @crop_stage.id, json["crop_stage_id"]
              end,
              duplicate_create_params: { required_gdd: 200.0 },
              invalid_param_key: :required_gdd,
              invalid_param_value: "invalid",
              update_factory_attrs: { required_gdd: 150.0 },
              update_params: { required_gdd: 250.0 },
              assert_update_json: proc do |json|
                assert_equal 250.0, json["required_gdd"]
              end,
              assert_update_persisted: proc do |requirement|
                requirement.reload
                assert_equal 250.0, requirement.required_gdd
              end,
              other_user_factory_attrs: { required_gdd: 150.0 },
              other_user_update_params: { required_gdd: 250.0 },
              assert_other_user_unchanged: proc do |requirement|
                requirement.reload
                assert_equal 150.0, requirement.required_gdd
              end
            })
          end
        end
      end
    end
  end
end
