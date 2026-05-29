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

            MastersCropStageRequirementApiTestCases.define(self, {
              matrix: :smoke,
              resource_label: "temperature_requirement",
              model: TemperatureRequirement,
              factory: :temperature_requirement,
              param_key: :temperature_requirement,
              singular_name: "TemperatureRequirement",
              path: ->(t, crop, stage) { t.api_v1_masters_crop_crop_stage_temperature_requirement_path(crop, stage) },
              show_factory_attrs: { base_temperature: 10.0, optimal_min: 15.0, optimal_max: 25.0 },
              assert_show_json: proc do |json, requirement|
                assert_equal requirement.id, json["id"]
                assert_equal 10.0, json["base_temperature"]
                assert_equal 15.0, json["optimal_min"]
                assert_equal 25.0, json["optimal_max"]
              end,
              create_params: {
                base_temperature: 12.0,
                optimal_min: 18.0,
                optimal_max: 28.0,
                low_stress_threshold: 5.0,
                high_stress_threshold: 35.0,
                frost_threshold: 0.0,
                sterility_risk_threshold: 40.0,
                max_temperature: 45.0
              },
              assert_create_json: proc do |json|
                assert_equal 12.0, json["base_temperature"]
                assert_equal 18.0, json["optimal_min"]
                assert_equal 28.0, json["optimal_max"]
                assert_equal @crop_stage.id, json["crop_stage_id"]
              end,
              duplicate_create_params: { base_temperature: 12.0 },
              invalid_param_key: :base_temperature,
              invalid_param_value: "invalid",
              update_factory_attrs: { base_temperature: 10.0, optimal_min: 15.0 },
              update_params: { base_temperature: 12.0, optimal_min: 18.0 },
              assert_update_json: proc do |json|
                assert_equal 12.0, json["base_temperature"]
                assert_equal 18.0, json["optimal_min"]
              end,
              assert_update_persisted: proc do |requirement|
                requirement.reload
                assert_equal 12.0, requirement.base_temperature
                assert_equal 18.0, requirement.optimal_min
              end,
              other_user_factory_attrs: { base_temperature: 10.0 },
              other_user_update_params: { base_temperature: 12.0 },
              assert_other_user_unchanged: proc do |requirement|
                requirement.reload
                assert_equal 10.0, requirement.base_temperature
              end
            })
          end
        end
      end
    end
  end
end
