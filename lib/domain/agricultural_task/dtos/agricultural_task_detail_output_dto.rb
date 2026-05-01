# frozen_string_literal: true

require "forwardable"

module Domain
  module AgriculturalTask
    module Dtos
      class AgriculturalTaskDetailOutputDto
        extend Forwardable

        def_delegators :task, :id, :user_id, :name, :description, :time_per_sqm, :weather_dependency,
                       :required_tools, :skill_level, :region, :task_type, :is_reference, :created_at, :updated_at

        attr_reader :task, :associated_crops

        def initialize(task:, associated_crops:)
          @task = task
          @associated_crops = associated_crops
        end

        def crops
          associated_crops
        end
      end
    end
  end
end
