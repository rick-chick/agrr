# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      class PlanSaveCropTaskTemplateAttributesMapper
        # @param link_row [Dtos::PublicPlanSaveCropTaskTemplateLinkRow]
        # @param task_row [Dtos::PublicPlanSaveAgriculturalTaskReferenceRow]
        # @param user_task_name [String, nil] persisted user AgriculturalTask name (wins over reference template)
        # @return [Hash]
        def self.attributes_for_create(link_row:, task_row:, user_task_name: nil)
          {
            name: user_task_name.presence || link_row.name.presence || task_row.name,
            description: link_row.description.nil? ? task_row.description : link_row.description,
            time_per_sqm: link_row.time_per_sqm.nil? ? task_row.time_per_sqm : link_row.time_per_sqm,
            weather_dependency: link_row.weather_dependency.nil? ? task_row.weather_dependency : link_row.weather_dependency,
            required_tools: tools_for_create(link_row, task_row),
            skill_level: link_row.skill_level.nil? ? task_row.skill_level : link_row.skill_level,
            task_type: link_row.task_type.nil? ? task_row.task_type : link_row.task_type,
            task_type_id: link_row.task_type_id.nil? ? task_row.task_type_id : link_row.task_type_id,
            is_reference: link_row.is_reference
          }
        end

        def self.tools_for_create(link_row, task_row)
          tools = link_row.required_tools.nil? ? task_row.required_tools : link_row.required_tools
          return [] if tools.nil?

          Array(tools).dup
        end
        private_class_method :tools_for_create
      end
    end
  end
end
