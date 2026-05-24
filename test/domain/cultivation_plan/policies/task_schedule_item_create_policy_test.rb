# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Policies
      class TaskScheduleItemCreatePolicyTest < DomainLibTestCase
        test "validate_crop_selection! passes when crop ids match" do
          TaskScheduleItemCreatePolicy.validate_crop_selection!(
            field_cultivation_crop_id: 5,
            submitted_crop_id: 5
          )
        end

        test "validate_crop_selection! raises when crop ids mismatch" do
          error = assert_raises(Domain::Shared::Exceptions::RecordInvalid) do
            TaskScheduleItemCreatePolicy.validate_crop_selection!(
              field_cultivation_crop_id: 5,
              submitted_crop_id: 9
            )
          end
          assert_includes error.errors["base"].first, "作物"
        end

        test "validate_template! raises when template crop does not match field crop" do
          template = Dtos::TaskScheduleCropTaskTemplateSnapshot.new(
            id: 1,
            crop_id: 99,
            name: "T",
            description: nil,
            task_type: nil,
            weather_dependency: nil,
            time_per_sqm: nil,
            agricultural_task_id: 1
          )

          assert_raises(Domain::Shared::Exceptions::RecordInvalid) do
            TaskScheduleItemCreatePolicy.validate_template!(field_crop_id: 5, template: template)
          end
        end

        test "build_create_attributes uses template name when name omitted" do
          template = Dtos::TaskScheduleCropTaskTemplateSnapshot.new(
            id: 1,
            crop_id: 5,
            name: "テンプレ作業",
            description: "説明",
            task_type: Domain::AgriculturalTask::Constants::ScheduleItemTypes::FIELD_WORK,
            weather_dependency: "low",
            time_per_sqm: 0.2,
            agricultural_task_id: 3
          )

          attrs = TaskScheduleItemCreatePolicy.build_create_attributes(
            { field_cultivation_id: 1, name: nil },
            template: template
          )

          assert_equal "テンプレ作業", attrs[:name]
          assert_equal "template_entry", attrs[:source]
        end
      end
    end
  end
end
