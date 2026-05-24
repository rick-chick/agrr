# frozen_string_literal: true

module Adapters
  module Crop
    module Mappers
      class CropTaskTemplateAgrrFormatMapper
        def self.build_array(templates)
          Array(templates).map { |template| build(template) }
        end

        def self.build(template)
          {
            "task_id" => agrr_task_id(template).to_s,
            "name" => template.name,
            "description" => template.description,
            "time_per_sqm" => template.time_per_sqm&.to_f,
            "weather_dependency" => template.weather_dependency,
            "required_tools" => template.required_tools || [],
            "skill_level" => template.skill_level
          }.compact
        end

        def self.agrr_task_id(template)
          template.agricultural_task_id || template.id
        end

        private_class_method :agrr_task_id
      end
    end
  end
end
