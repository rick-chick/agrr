# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      # 作物詳細 HTML のタスクブループリント表示用（ActiveRecord をビューに渡さない）。
      class CropTaskScheduleBlueprintRead
        attr_reader :id, :gdd_trigger, :priority, :task_type, :description, :stage_name, :agricultural_task_name

        def initialize(id:, gdd_trigger:, priority:, task_type:, description:, stage_name:, agricultural_task_name:)
          @id = id
          @gdd_trigger = gdd_trigger
          @priority = priority
          @task_type = task_type
          @description = description
          @stage_name = stage_name
          @agricultural_task_name = agricultural_task_name
        end
      end
    end
  end
end
