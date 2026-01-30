# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Dtos
      class AgriculturalTaskCreateInputDto
        attr_reader :name, :description, :time_per_sqm, :weather_dependency,
                    :required_tools, :skill_level, :region, :task_type

        def initialize(name:, description: nil, time_per_sqm: nil, weather_dependency: nil,
                       required_tools: nil, skill_level: nil, region: nil, task_type: nil)
          @name = name
          @description = description
          @time_per_sqm = time_per_sqm
          @weather_dependency = weather_dependency
          @required_tools = required_tools || []
          @skill_level = skill_level
          @region = region
          @task_type = task_type
        end

        def self.from_hash(hash)
          pp = hash[:agricultural_task] || hash
          new(
            name: pp[:name],
            description: pp[:description],
            time_per_sqm: pp[:time_per_sqm],
            weather_dependency: pp[:weather_dependency],
            required_tools: pp[:required_tools],
            skill_level: pp[:skill_level],
            region: pp[:region],
            task_type: pp[:task_type]
          )
        end
      end
    end
  end
end
