# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      module TaskScheduleTimelineReadSnapshotMapper
        Snapshot = Dtos::TaskScheduleTimelineSnapshot

        module_function

        def from_snapshots(plan:, fields:, scheduled_dates:)
          Snapshot.new(
            plan: plan,
            fields: fields,
            scheduled_dates: scheduled_dates
          )
        end

        def load_snapshot(read_gateway:, plan_id:)
          from_snapshots(
            plan: read_gateway.find_timeline_plan_read_by_plan_id(plan_id: plan_id),
            fields: TaskScheduleTimelineFieldReadMapper.from_read_snapshots(
              context_snapshots: read_gateway.list_timeline_field_context_snapshots_by_plan_id(plan_id: plan_id),
              schedule_rows: read_gateway.list_timeline_schedule_row_snapshots_by_plan_id(plan_id: plan_id)
            ),
            scheduled_dates: read_gateway.list_timeline_scheduled_dates_by_plan_id(plan_id: plan_id)
          )
        end
      end
    end
  end
end
