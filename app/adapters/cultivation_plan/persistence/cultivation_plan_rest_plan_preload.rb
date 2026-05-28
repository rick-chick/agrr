# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Persistence
      # REST 栽培計画の AR preload / narrow find（auth 非受け。認可は Interactor + Policy）。
      module CultivationPlanRestPlanPreload
        module_function

        CROP_WITH_STAGES = { crop: :crop_stages }.freeze

        REST_PLAN_INCLUDES = [
          :farm,
          :cultivation_plan_fields,
          { cultivation_plan_crops: CROP_WITH_STAGES },
          { field_cultivations: [ :cultivation_plan_field, { cultivation_plan_crop: CROP_WITH_STAGES } ] }
        ].freeze

        # @param plan_id [Integer, String]
        # @return [::CultivationPlan]
        # @raise [ActiveRecord::RecordNotFound]
        def find_by_plan_id(plan_id:)
          pid = plan_id.to_i
          ::CultivationPlan.includes(REST_PLAN_INCLUDES).find(pid)
        end
      end
    end
  end
end
