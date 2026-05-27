# frozen_string_literal: true

require "test_helper"

module Adapters
  module CultivationPlan
    class PlanSaveTaskScheduleAgriculturalTaskResolverTest < ActiveSupport::TestCase
      include PlanSaveTestSupport

      test "mapped_agricultural_task_id returns id when schedule item already references user task" do
        user = unique_test_user
        user_task = ::AgriculturalTask.create!(
          user: user,
          name: "UserOwned#{SecureRandom.hex(4)}",
          is_reference: false,
          region: "jp",
          time_per_sqm: 1.0,
          required_tools: []
        )

        ref_farm = ensure_reference_farm
        ref_crop = build_reference_crop(name: "ResCrop#{SecureRandom.hex(4)}")
        ref_plan, _, _, fc = build_public_plan_with_field_cultivation(
          farm: ref_farm,
          ref_crop: ref_crop,
          plan_name: "ResolverOwn#{SecureRandom.hex(4)}"
        )
        ts = TaskSchedule.create!(
          cultivation_plan: ref_plan,
          field_cultivation: fc,
          category: "general",
          status: "active",
          generated_at: Time.current
        )
        item = TaskScheduleItem.create!(
          task_schedule: ts,
          task_type: TaskScheduleItem::FIELD_WORK_TYPE,
          name: "item",
          source: "agrr",
          status: TaskScheduleItem::STATUSES[:planned],
          gdd_trigger: 10.0,
          agricultural_task: user_task
        )

        resolver = PlanSaveTaskScheduleAgriculturalTaskResolver.new(
          user_id: user.id,
          reference_agricultural_task_id_to_user_task_id: {},
          plan_save_user_agricultural_task_gateway:
            Adapters::CultivationPlan::Gateways::PlanSaveUserAgriculturalTaskActiveRecordGateway.new
        )

        assert_equal user_task.id, resolver.mapped_agricultural_task_id(item)
      end

      test "mapped_agricultural_task_id resolves reference task via ctx map" do
        user = unique_test_user
        ref_task = ::AgriculturalTask.create!(
          user: nil,
          name: "RefTask#{SecureRandom.hex(4)}",
          is_reference: true,
          region: "jp",
          time_per_sqm: 1.0
        )
        user_task = ::AgriculturalTask.create!(
          user: user,
          name: "Copy#{SecureRandom.hex(4)}",
          is_reference: false,
          region: "jp",
          source_agricultural_task_id: ref_task.id,
          time_per_sqm: 1.0,
          required_tools: []
        )

        ref_farm = ensure_reference_farm
        ref_crop = build_reference_crop(name: "ResCrop2_#{SecureRandom.hex(4)}")
        ref_plan, _, _, fc = build_public_plan_with_field_cultivation(
          farm: ref_farm,
          ref_crop: ref_crop,
          plan_name: "ResolverMap#{SecureRandom.hex(4)}"
        )
        ts = TaskSchedule.create!(
          cultivation_plan: ref_plan,
          field_cultivation: fc,
          category: "general",
          status: "active",
          generated_at: Time.current
        )
        item = TaskScheduleItem.create!(
          task_schedule: ts,
          task_type: TaskScheduleItem::FIELD_WORK_TYPE,
          name: "item",
          source: "agrr",
          status: TaskScheduleItem::STATUSES[:planned],
          gdd_trigger: 10.0,
          agricultural_task: ref_task
        )

        resolver = PlanSaveTaskScheduleAgriculturalTaskResolver.new(
          user_id: user.id,
          reference_agricultural_task_id_to_user_task_id: { ref_task.id => user_task.id },
          plan_save_user_agricultural_task_gateway:
            Adapters::CultivationPlan::Gateways::PlanSaveUserAgriculturalTaskActiveRecordGateway.new
        )

        assert_equal user_task.id, resolver.mapped_agricultural_task_id(item)
      end
    end
  end
end
