# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      class PlanSaveAgriculturalTaskAttributesMapper
        # @param row [Dtos::PublicPlanSaveAgriculturalTaskReferenceRow]
        # @param region [String, nil] farm region fallback
        # @return [Hash]
        def self.attributes_for_create(row:, region:)
          {
            name: row.name,
            description: row.description,
            time_per_sqm: row.time_per_sqm,
            weather_dependency: row.weather_dependency,
            required_tools: duplicate_tools(row.required_tools),
            skill_level: row.skill_level,
            task_type: row.task_type,
            task_type_id: row.task_type_id,
            region: row.region || region,
            is_reference: false,
            source_agricultural_task_id: row.reference_agricultural_task_id
          }
        end

        def self.duplicate_tools(tools)
          return [] if tools.nil?

          Array(tools).dup
        end
        private_class_method :duplicate_tools
      end
    end
  end
end
