# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropDetailOutput
        attr_reader :crop, :task_schedule_blueprints, :available_agricultural_tasks, :selected_task_ids, :associated_pests

        def initialize(
          crop:,
          task_schedule_blueprints: [],
          available_agricultural_tasks: [],
          selected_task_ids: [],
          associated_pests: []
        )
          @crop = crop
          @task_schedule_blueprints = task_schedule_blueprints
          @available_agricultural_tasks = available_agricultural_tasks
          @selected_task_ids = selected_task_ids
          @associated_pests = associated_pests
        end
      end
    end
  end
end
