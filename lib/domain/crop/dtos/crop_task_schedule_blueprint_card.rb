# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      # 作物詳細のブループリントボード用（AR をビューに渡さない）。
      class CropTaskScheduleBlueprintCard
        class TaskNameWrapper
          attr_reader :name
          def initialize(name)
            @name = name
          end
        end

        attr_reader :id, :gdd_trigger, :priority, :task_type, :description, :stage_name, :agricultural_task_name

        def self.model_name
          @model_name ||= Domain::Shared::FormModelName.from_logical_name("CropTaskScheduleBlueprint")
        end

        def model_name
          self.class.model_name
        end

        def initialize(id:, gdd_trigger:, priority:, task_type:, description:, stage_name:, agricultural_task_name:)
          @id = id
          @gdd_trigger = gdd_trigger
          @priority = priority
          @task_type = task_type
          @description = description
          @stage_name = stage_name
          @agricultural_task_name = agricultural_task_name
        end

        def persisted?
          true
        end

        def to_param
          id.to_s
        end

        def to_model
          self
        end

        def agricultural_task
          return nil if Domain::Shared.blank?(agricultural_task_name)

          TaskNameWrapper.new(agricultural_task_name)
        end
      end
    end
  end
end
