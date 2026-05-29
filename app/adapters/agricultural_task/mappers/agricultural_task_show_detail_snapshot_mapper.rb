# frozen_string_literal: true

module Adapters
  module AgriculturalTask
    module Mappers
      module AgriculturalTaskShowDetailSnapshotMapper
        Dtos = Domain::AgriculturalTask::Dtos

        module_function

        def from_model(record)
          crop_snapshots = record.crops.order(:name).map { |crop| crop_snapshot_from(crop) }
          Dtos::AgriculturalTaskShowDetailSnapshot.new(
            task: task_snapshot_from(record),
            crops: crop_snapshots
          )
        end

        def task_snapshot_from(record)
          Dtos::AgriculturalTaskShowDetailTaskSnapshot.new(
            id: record.id,
            user_id: record.user_id,
            name: record.name,
            description: record.description,
            time_per_sqm: record.time_per_sqm,
            weather_dependency: record.weather_dependency,
            required_tools: record.required_tools || [],
            skill_level: record.skill_level,
            region: record.region,
            task_type: record.task_type,
            is_reference: record.is_reference,
            created_at: record.created_at,
            updated_at: record.updated_at
          )
        end

        def crop_snapshot_from(record)
          Dtos::AgriculturalTaskShowDetailCropSnapshot.new(
            id: record.id,
            user_id: record.user_id,
            name: record.name,
            variety: record.variety,
            is_reference: record.is_reference,
            area_per_unit: record.area_per_unit,
            revenue_per_area: record.revenue_per_area,
            region: record.region,
            created_at: record.created_at,
            updated_at: record.updated_at
          )
        end
      end
    end
  end
end
