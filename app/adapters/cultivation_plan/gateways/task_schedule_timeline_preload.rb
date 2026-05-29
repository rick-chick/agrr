# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      module TaskScheduleTimelinePreload
        SCHEDULE_INCLUDES = [
          { task_schedule_items: :agricultural_task },
          field_cultivation: [
            :cultivation_plan_field,
            {
              cultivation_plan_crop: {
                crop: [
                  :agricultural_tasks,
                  { crop_task_templates: :agricultural_task }
                ]
              }
            }
          ]
        ].freeze

        LoadResult = Data.define(:plan, :schedules, :scheduled_dates, :timeline_generated_at)

        module_function

        # @param plan_id [Integer, String]
        # @return [LoadResult]
        def load(plan_id:)
          plan = ::CultivationPlan.includes(:farm).find(plan_id)
          schedules = TaskSchedule.where(cultivation_plan_id: plan.id).includes(SCHEDULE_INCLUDES)
          timeline_generated_at = schedules.maximum(:generated_at)
          scheduled_dates = TaskScheduleItem
                              .joins(:task_schedule)
                              .where(task_schedules: { cultivation_plan_id: plan.id })
                              .where.not(scheduled_date: nil)
                              .pluck(:scheduled_date)

          LoadResult.new(
            plan: plan,
            schedules: schedules.to_a,
            scheduled_dates: scheduled_dates,
            timeline_generated_at: timeline_generated_at
          )
        end
      end
    end
  end
end
