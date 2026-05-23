# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      # ブループリント削除成功時の Turbo Stream 再描画用（AR をビューに渡さない）。
      class CropTaskScheduleBlueprintDestroyOutput
        attr_reader :blueprint_id,
                    :crop_master_form_snapshot,
                    :task_schedule_blueprint_cards,
                    :available_agricultural_tasks,
                    :selected_task_ids

        def initialize(
          blueprint_id:,
          crop_master_form_snapshot:,
          task_schedule_blueprint_cards:,
          available_agricultural_tasks:,
          selected_task_ids:
        )
          @blueprint_id = blueprint_id
          @crop_master_form_snapshot = crop_master_form_snapshot
          @task_schedule_blueprint_cards = task_schedule_blueprint_cards
          @available_agricultural_tasks = available_agricultural_tasks
          @selected_task_ids = selected_task_ids
        end
      end
    end
  end
end
