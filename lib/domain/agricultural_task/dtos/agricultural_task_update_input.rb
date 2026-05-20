# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Dtos
      class AgriculturalTaskUpdateInput
        attr_reader :id, :name, :description, :time_per_sqm, :weather_dependency,
                    :required_tools, :skill_level, :region, :task_type, :is_reference, :selected_crop_ids

        def initialize(id:, name: nil, description: nil, time_per_sqm: nil, weather_dependency: nil,
                       required_tools: nil, skill_level: nil, region: nil, task_type: nil, is_reference: nil,
                       selected_crop_ids: nil)
          @id = id
          @name = name
          @description = description
          @time_per_sqm = time_per_sqm
          @weather_dependency = weather_dependency
          @required_tools = required_tools
          @skill_level = skill_level
          @region = region
          @task_type = task_type
          @is_reference = is_reference
          @selected_crop_ids = selected_crop_ids
        end

        def self.from_hash(hash, task_id)
          h = hash.respond_to?(:deep_symbolize_keys) ? hash.deep_symbolize_keys : hash
          pp = h[:agricultural_task] || h
          selected = h.key?(:selected_crop_ids) ? h[:selected_crop_ids] : nil
          new(
            id: task_id,
            name: pp[:name],
            description: pp[:description],
            time_per_sqm: pp[:time_per_sqm],
            weather_dependency: pp[:weather_dependency],
            required_tools: pp[:required_tools],
            skill_level: pp[:skill_level],
            region: pp[:region],
            task_type: pp[:task_type],
            is_reference: pp[:is_reference],
            selected_crop_ids: selected
          )
        end
      end
    end
  end
end
