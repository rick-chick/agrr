# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # 公開プラン保存: 参照 CropTaskTemplate 1 行。
      class PublicPlanSaveCropTaskTemplateLinkRow
        attr_reader :reference_crop_id,
                    :name,
                    :description,
                    :time_per_sqm,
                    :weather_dependency,
                    :required_tools,
                    :skill_level,
                    :task_type,
                    :task_type_id,
                    :is_reference

        def initialize(
          reference_crop_id:,
          name:,
          description: nil,
          time_per_sqm: nil,
          weather_dependency: nil,
          required_tools: nil,
          skill_level: nil,
          task_type: nil,
          task_type_id: nil,
          is_reference: false
        )
          @reference_crop_id = reference_crop_id.to_i
          @name = name.nil? ? nil : name.to_s
          @description = description
          @time_per_sqm = time_per_sqm
          @weather_dependency = weather_dependency
          @required_tools = required_tools
          @skill_level = skill_level
          @task_type = task_type
          @task_type_id = task_type_id
          @is_reference = is_reference == true
          freeze
        end
      end
    end
  end
end
