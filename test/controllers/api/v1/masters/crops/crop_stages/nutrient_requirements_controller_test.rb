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

            MastersCropStageRequirementApiTestCases.define(self, {
              resource_label: "nutrient_requirement",
              model: NutrientRequirement,
              factory: :nutrient_requirement,
              param_key: :nutrient_requirement,
              singular_name: "NutrientRequirement",
              path: ->(t, crop, stage) { t.api_v1_masters_crop_crop_stage_nutrient_requirement_path(crop, stage) },
              show_factory_attrs: {
                daily_uptake_n: 1.5, daily_uptake_p: 0.3, daily_uptake_k: 1.2, region: "関東"
              },
              assert_show_json: proc do |json, requirement|
                assert_equal requirement.id, json["id"]
                assert_equal 1.5, json["daily_uptake_n"]
                assert_equal 0.3, json["daily_uptake_p"]
                assert_equal 1.2, json["daily_uptake_k"]
                assert_equal "関東", json["region"]
              end,
              create_params: {
                daily_uptake_n: 2.0,
                daily_uptake_p: 0.4,
                daily_uptake_k: 1.8,
                region: "北海道"
              },
              assert_create_json: proc do |json|
                assert_equal 2.0, json["daily_uptake_n"]
                assert_equal 0.4, json["daily_uptake_p"]
                assert_equal 1.8, json["daily_uptake_k"]
                assert_equal "北海道", json["region"]
                assert_equal @crop_stage.id, json["crop_stage_id"]
              end,
              duplicate_create_params: { daily_uptake_n: 2.0 },
              invalid_param_key: :daily_uptake_n,
              invalid_param_value: "invalid",
              update_factory_attrs: {
                daily_uptake_n: 1.5, daily_uptake_p: 0.3, daily_uptake_k: 1.2, region: "関東"
              },
              update_params: {
                daily_uptake_n: 2.5,
                daily_uptake_p: 0.5,
                daily_uptake_k: 2.0,
                region: "九州"
              },
              assert_update_json: proc do |json|
                assert_equal 2.5, json["daily_uptake_n"]
                assert_equal 0.5, json["daily_uptake_p"]
                assert_equal 2.0, json["daily_uptake_k"]
                assert_equal "九州", json["region"]
              end,
              assert_update_persisted: proc do |requirement|
                requirement.reload
                assert_equal 2.5, requirement.daily_uptake_n
                assert_equal 0.5, requirement.daily_uptake_p
                assert_equal 2.0, requirement.daily_uptake_k
                assert_equal "九州", requirement.region
              end,
              other_user_factory_attrs: { daily_uptake_n: 1.5 },
              other_user_update_params: { daily_uptake_n: 2.5 },
              assert_other_user_unchanged: proc do |requirement|
                requirement.reload
                assert_equal 1.5, requirement.daily_uptake_n
              end
            })
          end
        end
      end
    end
  end
end
