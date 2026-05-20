# frozen_string_literal: true

module Adapters
  module AgriculturalTask
    module Mappers
      class AgriculturalTaskMapper
        def self.agricultural_task_entity_from_record(record)
          Domain::AgriculturalTask::Entities::AgriculturalTaskEntity.new(
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

        def self.detail_output_dto_from_record(record)
          crops = record.crops.order(:name).map do |c|
            Domain::Crop::Entities::CropEntity.new(
              id: c.id,
              user_id: c.user_id,
              name: c.name,
              variety: c.variety,
              is_reference: c.is_reference,
              area_per_unit: c.area_per_unit,
              revenue_per_area: c.revenue_per_area,
              region: c.region,
              groups: [],
              crop_stages: [],
              created_at: c.created_at,
              updated_at: c.updated_at
            )
          end

          Domain::AgriculturalTask::Dtos::AgriculturalTaskDetailOutput.new(
            task: agricultural_task_entity_from_record(record),
            associated_crops: crops
          )
        end
      end
    end
  end
end
