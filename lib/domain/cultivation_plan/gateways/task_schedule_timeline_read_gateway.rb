# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      class TaskScheduleTimelineReadGateway
        Snapshot = Dtos::TaskScheduleTimelineSnapshot

        def find_timeline_plan_read_by_plan_id(plan_id:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        def list_timeline_scheduled_dates_by_plan_id(plan_id:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        # @return [Array<Snapshot::FieldContextSnapshot>]
        def list_timeline_field_context_snapshots_by_plan_id(plan_id:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        # @return [Array<Snapshot::ScheduleRowSnapshot>]
        def list_timeline_schedule_row_snapshots_by_plan_id(plan_id:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end
      end
    end
  end
end
