# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Mappers
      module TaskScheduleGenerationPlanRowSnapshotMapper
        Snapshot = Domain::CultivationPlan::Dtos::TaskScheduleGenerationReadSnapshots::PlanRowSnapshot

        module_function

        # @param plan [::CultivationPlan]
        # @return [Snapshot]
        def from_model(plan)
          Snapshot.new(
            id: plan.id,
            predicted_weather_data: plan.predicted_weather_data,
            calculated_planning_start_date: plan.calculated_planning_start_date
          )
        end
      end
    end
  end
end
