# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Entities
      class AgriculturalTaskEntity
        attr_reader :id, :user_id, :name, :description, :time_per_sqm, :weather_dependency,
                    :required_tools, :skill_level, :region, :task_type, :is_reference, :created_at, :updated_at

        def initialize(attributes)
          @id = attributes[:id]
          @user_id = attributes[:user_id]
          @name = attributes[:name]
          @description = attributes[:description]
          @time_per_sqm = attributes[:time_per_sqm]
          @weather_dependency = attributes[:weather_dependency]
          @required_tools = attributes[:required_tools] || []
          @skill_level = attributes[:skill_level]
          @region = attributes[:region]
          @task_type = attributes[:task_type]
          @is_reference = attributes[:is_reference]
          @created_at = attributes[:created_at]
          @updated_at = attributes[:updated_at]

          validate!
        end

        def reference?
          !!is_reference
        end

        def to_param
          id.to_s
        end

        def to_hash
          {
            id: id,
            user_id: user_id,
            name: name,
            description: description,
            time_per_sqm: time_per_sqm,
            weather_dependency: weather_dependency,
            required_tools: required_tools,
            skill_level: skill_level,
            region: region,
            task_type: task_type,
            is_reference: is_reference,
            created_at: created_at,
            updated_at: updated_at
          }
        end

        private

        def validate!
          raise ArgumentError, "Name is required" if Domain::Shared::ValidationHelpers.blank?(name)
          validate_region!
        end

        def validate_region!
          return if region.nil?

          valid_regions = %w[jp us in]
          unless valid_regions.include?(region)
            raise ArgumentError, "Region must be one of: jp, us, in"
          end
        end
      end
    end
  end
end
