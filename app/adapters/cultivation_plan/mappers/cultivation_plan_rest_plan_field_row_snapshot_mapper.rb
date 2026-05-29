# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Mappers
      module CultivationPlanRestPlanFieldRowSnapshotMapper
        Dtos = Domain::CultivationPlan::Dtos

        module_function

        def from_field(field)
          Dtos::CultivationPlanRestPlanFieldRowSnapshot.new(
            id: field.id,
            name: field.name,
            area: field.area,
            daily_fixed_cost: field.daily_fixed_cost,
            display_name: field.display_name
          )
        end
      end
    end
  end
end
