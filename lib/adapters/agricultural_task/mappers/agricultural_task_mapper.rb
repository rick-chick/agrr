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
      end
    end
  end
end
