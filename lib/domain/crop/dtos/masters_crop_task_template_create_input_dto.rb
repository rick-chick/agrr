# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class MastersCropTaskTemplateCreateInputDto
        attr_reader :user_id,
          :crop_id,
          :agricultural_task_id,
          :name,
          :description,
          :time_per_sqm,
          :weather_dependency,
          :required_tools,
          :skill_level

        def initialize(user_id:, crop_id:, agricultural_task_id:, name: nil, description: nil, time_per_sqm: nil,
                       weather_dependency: nil, required_tools: nil, skill_level: nil)
          @user_id = user_id
          @crop_id = crop_id
          @agricultural_task_id = agricultural_task_id
          @name = name
          @description = description
          @time_per_sqm = time_per_sqm
          @weather_dependency = weather_dependency
          @required_tools = required_tools
          @skill_level = skill_level
        end
      end
    end
  end
end
