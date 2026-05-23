# frozen_string_literal: true

module Adapters
  module Crop
    module Mappers
      class CropTaskScheduleBlueprintCardMapper
        class << self
          def from_record(blueprint)
            Domain::Crop::Dtos::CropTaskScheduleBlueprintCard.new(
              id: blueprint.id,
              gdd_trigger: blueprint.gdd_trigger,
              priority: blueprint.priority,
              task_type: blueprint.task_type,
              description: blueprint.description,
              stage_name: blueprint.stage_name,
              agricultural_task_name: blueprint.agricultural_task&.name
            )
          end

          def from_records(blueprints)
            Array(blueprints).map { |bp| from_record(bp) }
          end
        end
      end
    end
  end
end
