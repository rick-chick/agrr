# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropTaskTemplatePersistAttributes
        attr_reader :name,
          :description,
          :time_per_sqm,
          :weather_dependency,
          :required_tools,
          :skill_level

        def initialize(name:, description:, time_per_sqm:, weather_dependency:, required_tools:, skill_level:)
          @name = name
          @description = description
          @time_per_sqm = time_per_sqm
          @weather_dependency = weather_dependency
          @required_tools = required_tools
          @skill_level = skill_level
        end

        def to_gateway_attrs
          {
            name: name,
            description: description,
            time_per_sqm: time_per_sqm,
            weather_dependency: weather_dependency,
            required_tools: required_tools,
            skill_level: skill_level
          }
        end
      end
    end
  end
end
