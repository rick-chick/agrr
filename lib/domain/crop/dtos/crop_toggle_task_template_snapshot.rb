# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      CropToggleTaskTemplateSnapshot = Struct.new(
        :available_agricultural_tasks,
        :selected_task_ids,
        :task_schedule_blueprints,
        keyword_init: true
      )
    end
  end
end
