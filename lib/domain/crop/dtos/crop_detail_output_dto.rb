# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropDetailOutputDto
        attr_reader :crop, :task_schedule_blueprints, :available_agricultural_tasks, :selected_task_ids

        def initialize(
          crop:,
          task_schedule_blueprints: [],
          available_agricultural_tasks: [],
          selected_task_ids: []
        )
          @crop = crop
          @task_schedule_blueprints = task_schedule_blueprints
          @available_agricultural_tasks = available_agricultural_tasks
          @selected_task_ids = selected_task_ids
        end
      end
    end
  end
end
