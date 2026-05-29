# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class TaskScheduleTimelineReadActiveRecordGateway <
          Domain::CultivationPlan::Gateways::TaskScheduleTimelineReadGateway
        Snapshot = Domain::CultivationPlan::Dtos::TaskScheduleTimelineSnapshot

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

        def find_timeline_plan_read_by_plan_id(plan_id:)
          plan = ::CultivationPlan.includes(:farm).find(plan_id)
          timeline_generated_at = TaskSchedule.where(cultivation_plan_id: plan.id).maximum(:generated_at)
          Snapshot::PlanRead.new(
            id: plan.id,
            display_name: plan.display_name,
            status: plan.status,
            planning_start_date: plan.planning_start_date,
            planning_end_date: plan.planning_end_date,
            timeline_generated_at: timeline_generated_at,
            farm_display_name: plan.farm.display_name,
            total_area: plan.total_area
          )
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def list_timeline_scheduled_dates_by_plan_id(plan_id:)
          ensure_plan_exists!(plan_id)
          TaskScheduleItem
            .joins(:task_schedule)
            .where(task_schedules: { cultivation_plan_id: plan_id })
            .where.not(scheduled_date: nil)
            .pluck(:scheduled_date)
        end

        def list_timeline_field_context_snapshots_by_plan_id(plan_id:)
          ensure_plan_exists!(plan_id)
          schedules = TaskSchedule.where(cultivation_plan_id: plan_id).includes(SCHEDULE_INCLUDES).to_a
          schedules.group_by(&:field_cultivation).map do |field_cultivation, _field_schedules|
            Mappers::TaskScheduleTimelineFieldReadSnapshotMapper.field_context_from(field_cultivation)
          end
        end

        def list_timeline_schedule_row_snapshots_by_plan_id(plan_id:)
          ensure_plan_exists!(plan_id)
          TaskSchedule.where(cultivation_plan_id: plan_id).includes(SCHEDULE_INCLUDES).map do |schedule|
            Mappers::TaskScheduleTimelineFieldReadSnapshotMapper.schedule_row_from(schedule)
          end
        end

        private

        def ensure_plan_exists!(plan_id)
          ::CultivationPlan.find(plan_id)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end
      end
    end
  end
end
