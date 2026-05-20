# frozen_string_literal: true

module Adapters
  module AgriculturalTask
    module Gateways
      class TaskScheduleActiveRecordGateway < Domain::AgriculturalTask::Gateways::TaskScheduleGateway
        def delete_all_for_field_category(cultivation_plan_id:, field_cultivation_id:, category:)
          ::TaskSchedule.where(
            cultivation_plan_id: cultivation_plan_id,
            field_cultivation_id: field_cultivation_id,
            category: category
          ).delete_all
        end

        # @param items [Array<Hash>] TaskScheduleItem 生成用の属性（:agricultural_task_id 等）
        def replace_schedule_for_field_category!(cultivation_plan_id:, field_cultivation_id:, category:, generated_at:, items:)
          plan = ::CultivationPlan.find(cultivation_plan_id)
          fc = ::FieldCultivation.find(field_cultivation_id)

          ::TaskSchedule.where(
            cultivation_plan_id: cultivation_plan_id,
            field_cultivation_id: field_cultivation_id,
            category: category
          ).delete_all

          schedule = ::TaskSchedule.new(
            cultivation_plan: plan,
            field_cultivation: fc,
            category: category,
            status: ::TaskSchedule::STATUSES[:active],
            source: "agrr",
            generated_at: generated_at
          )

          items.each { |attrs| schedule.task_schedule_items.build(attrs) }

          schedule.save!
          true
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        rescue ActiveRecord::RecordInvalid => e
          raise Domain::Shared::Exceptions::RecordInvalid, e.message
        end
      end
    end
  end
end
