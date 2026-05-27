# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # 公開プラン保存: 参照 AgriculturalTask 1 行（テンプレ link はネスト DTO）。
      class PublicPlanSaveAgriculturalTaskReferenceRow
        attr_reader :reference_agricultural_task_id,
                    :name,
                    :description,
                    :time_per_sqm,
                    :weather_dependency,
                    :required_tools,
                    :skill_level,
                    :task_type,
                    :task_type_id,
                    :region,
                    :linked_reference_crop_ids,
                    :template_links

        def initialize(
          reference_agricultural_task_id:,
          name:,
          description: nil,
          time_per_sqm: nil,
          weather_dependency: nil,
          required_tools: nil,
          skill_level: nil,
          task_type: nil,
          task_type_id: nil,
          region: nil,
          linked_reference_crop_ids: [],
          template_links: []
        )
          @reference_agricultural_task_id = reference_agricultural_task_id.to_i
          @name = name.nil? ? nil : name.to_s
          @description = description
          @time_per_sqm = time_per_sqm
          @weather_dependency = weather_dependency
          @required_tools = required_tools
          @skill_level = skill_level
          @task_type = task_type
          @task_type_id = task_type_id
          @region = region.nil? ? nil : region.to_s
          @linked_reference_crop_ids = Array(linked_reference_crop_ids).map(&:to_i).freeze
          @template_links = Array(template_links).freeze
          freeze
        end
      end
    end
  end
end
