# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      module TaskScheduleTimelineFieldReadMapper
        Snapshot = Dtos::TaskScheduleTimelineSnapshot
        FieldRead = Snapshot::FieldRead

        module_function

        # @param context_snapshots [Array<Snapshot::FieldContextSnapshot>]
        # @param schedule_rows [Array<Snapshot::ScheduleRowSnapshot>]
        # @return [Array<FieldRead>]
        def from_read_snapshots(context_snapshots:, schedule_rows:)
          schedules_by_field = schedule_rows.group_by(&:field_cultivation_id)
          context_snapshots.map do |context|
            schedules = Array(schedules_by_field[context.field_cultivation_id]).map(&:schedule)
            FieldRead.new(
              id: context.id,
              name: context.name,
              crop_name: context.crop_name,
              area_sqm: context.area_sqm,
              field_cultivation_id: context.field_cultivation_id,
              crop_id: context.crop_id,
              task_options: context.task_options,
              schedules: schedules
            )
          end
        end
      end
    end
  end
end
