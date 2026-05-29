# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Mappers
      module AgriculturalTaskShowDetailMapper
        module_function

        # @param snapshot [Dtos::AgriculturalTaskShowDetailSnapshot]
        # @return [Domain::AgriculturalTask::Dtos::AgriculturalTaskDetailOutput]
        def from_snapshot(snapshot)
          task_entity = task_entity_from_snapshot(snapshot.task)
          associated_crops = snapshot.crops.sort_by(&:name).map { |crop_row| crop_entity_from_snapshot(crop_row) }
          Dtos::AgriculturalTaskDetailOutput.new(task: task_entity, associated_crops: associated_crops)
        end

        def task_entity_from_snapshot(wire)
          Entities::AgriculturalTaskEntity.new(
            id: wire.id,
            user_id: wire.user_id,
            name: wire.name,
            description: wire.description,
            time_per_sqm: wire.time_per_sqm,
            weather_dependency: wire.weather_dependency,
            required_tools: wire.required_tools || [],
            skill_level: wire.skill_level,
            region: wire.region,
            task_type: wire.task_type,
            is_reference: wire.is_reference,
            created_at: wire.created_at,
            updated_at: wire.updated_at
          )
        end

        def crop_entity_from_snapshot(wire)
          Domain::Crop::Entities::CropEntity.new(
            id: wire.id,
            user_id: wire.user_id,
            name: wire.name,
            variety: wire.variety,
            is_reference: wire.is_reference,
            area_per_unit: wire.area_per_unit,
            revenue_per_area: wire.revenue_per_area,
            region: wire.region,
            groups: [],
            crop_stages: [],
            created_at: wire.created_at,
            updated_at: wire.updated_at
          )
        end
      end
    end
  end
end
