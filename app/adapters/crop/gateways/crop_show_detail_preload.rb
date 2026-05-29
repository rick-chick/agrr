# frozen_string_literal: true

module Adapters
  module Crop
    module Gateways
      module CropShowDetailPreload
        CROP_ASSOCIATION_PRELOAD_INCLUDES = {
          crop_stages: [ :temperature_requirement, :thermal_requirement, :sunshine_requirement, :nutrient_requirement ],
          agricultural_tasks: [],
          crop_task_templates: [ :agricultural_task ],
          crop_task_schedule_blueprints: [ :agricultural_task ],
          pests: []
        }.freeze

        module_function

        def find!(id)
          ::Crop.includes(CROP_ASSOCIATION_PRELOAD_INCLUDES).find(id)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end
      end
    end
  end
end
