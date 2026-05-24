# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module AgriculturalTask
    module Policies
      class CropTaskTemplateSyncPolicyTest < DomainLibTestCase
        test "crop_associate_region_filter は region があるときだけ値を返す" do
          assert_equal "jp", CropTaskTemplateSyncPolicy.crop_associate_region_filter(region: "jp")
          assert_nil CropTaskTemplateSyncPolicy.crop_associate_region_filter(region: nil)
          assert_nil CropTaskTemplateSyncPolicy.crop_associate_region_filter(region: "")
        end

        test "allowed_crop_ids intersects selected with scope" do
          allowed = CropTaskTemplateSyncPolicy.allowed_crop_ids(
            scope_crop_ids: [1, 2, 3],
            selected_crop_ids: [2, 4, "2"]
          )

          assert_equal [2], allowed
        end

        test "skip_template_create? and skip_template_remove? encode idempotent sync rules" do
          assert CropTaskTemplateSyncPolicy.skip_template_create?(crop_found: false, template_exists: false)
          assert CropTaskTemplateSyncPolicy.skip_template_create?(crop_found: true, template_exists: true)
          assert_not CropTaskTemplateSyncPolicy.skip_template_create?(crop_found: true, template_exists: false)

          assert CropTaskTemplateSyncPolicy.skip_template_remove?(crop_found: false, template_exists: true)
          assert CropTaskTemplateSyncPolicy.skip_template_remove?(crop_found: true, template_exists: false)
          assert_not CropTaskTemplateSyncPolicy.skip_template_remove?(crop_found: true, template_exists: true)
        end

        test "crops_to_add and crops_to_remove compute set difference" do
          allowed = [1, 2]
          current = [2, 3]

          assert_equal [1], CropTaskTemplateSyncPolicy.crops_to_add(
            allowed_crop_ids: allowed,
            current_template_crop_ids: current
          )
          assert_equal [3], CropTaskTemplateSyncPolicy.crops_to_remove(
            allowed_crop_ids: allowed,
            current_template_crop_ids: current
          )
        end

        test "template_attributes_from_task_entity copies task fields" do
          task = Domain::AgriculturalTask::Entities::AgriculturalTaskEntity.new(
            id: 1,
            user_id: 10,
            name: "剪定",
            description: "desc",
            time_per_sqm: 0.5,
            weather_dependency: "low",
            required_tools: %w[ハサミ],
            skill_level: "beginner",
            region: "jp",
            task_type: "work",
            is_reference: false
          )

          attrs = CropTaskTemplateSyncPolicy.template_attributes_from_task_entity(task)

          assert_equal(
            {
              name: "剪定",
              description: "desc",
              time_per_sqm: 0.5,
              weather_dependency: "low",
              required_tools: %w[ハサミ],
              skill_level: "beginner"
            },
            attrs
          )
        end
      end
    end
  end
end
