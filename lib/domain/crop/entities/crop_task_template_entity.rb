# frozen_string_literal: true

module Domain
  module Crop
    module Entities
      class CropTaskTemplateEntity
        attr_reader :id,
          :crop_id,
          :agricultural_task_id,
          :name,
          :description,
          :time_per_sqm,
          :weather_dependency,
          :required_tools,
          :skill_level,
          :created_at,
          :updated_at

        def initialize(
          id:,
          crop_id:,
          agricultural_task_id:,
          name:,
          description:,
          time_per_sqm:,
          weather_dependency:,
          required_tools:,
          skill_level:,
          created_at:,
          updated_at:
        )
          @id = id
          @crop_id = crop_id
          @agricultural_task_id = agricultural_task_id
          @name = name
          @description = description
          @time_per_sqm = time_per_sqm
          @weather_dependency = weather_dependency
          @required_tools = required_tools || []
          @skill_level = skill_level
          @created_at = created_at
          @updated_at = updated_at
        end
      end
    end
  end
end
