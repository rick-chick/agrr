# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Dtos
      class AgriculturalTaskShowDetailTaskSnapshot
        attr_reader :id, :user_id, :name, :description, :time_per_sqm, :weather_dependency,
                    :required_tools, :skill_level, :region, :task_type, :is_reference,
                    :created_at, :updated_at

        def initialize(id:, user_id:, name:, description:, time_per_sqm:, weather_dependency:,
                       required_tools:, skill_level:, region:, task_type:, is_reference:,
                       created_at:, updated_at:)
          @id = id
          @user_id = user_id
          @name = name
          @description = description
          @time_per_sqm = time_per_sqm
          @weather_dependency = weather_dependency
          @required_tools = required_tools
          @skill_level = skill_level
          @region = region
          @task_type = task_type
          @is_reference = is_reference
          @created_at = created_at
          @updated_at = updated_at
          freeze
        end
      end

      class AgriculturalTaskShowDetailCropSnapshot
        attr_reader :id, :user_id, :name, :variety, :is_reference, :area_per_unit,
                    :revenue_per_area, :region, :created_at, :updated_at

        def initialize(id:, user_id:, name:, variety:, is_reference:, area_per_unit:,
                       revenue_per_area:, region:, created_at:, updated_at:)
          @id = id
          @user_id = user_id
          @name = name
          @variety = variety
          @is_reference = is_reference
          @area_per_unit = area_per_unit
          @revenue_per_area = revenue_per_area
          @region = region
          @created_at = created_at
          @updated_at = updated_at
          freeze
        end
      end

      class AgriculturalTaskShowDetailSnapshot
        attr_reader :task, :crops

        def initialize(task:, crops:)
          @task = task
          @crops = crops
          freeze
        end
      end
    end
  end
end
