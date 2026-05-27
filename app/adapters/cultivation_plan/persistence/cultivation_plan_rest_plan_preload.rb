# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Persistence
      # REST 栽培計画の AR preload / narrow find（auth 非受け。認可は Interactor + Policy）。
      module CultivationPlanRestPlanPreload
        module_function

        CROP_WITH_STAGES = { crop: :crop_stages }.freeze

        PRIVATE_PRELOAD = [
          :cultivation_plan_fields,
          { cultivation_plan_crops: CROP_WITH_STAGES },
          { field_cultivations: [ :cultivation_plan_field, { cultivation_plan_crop: CROP_WITH_STAGES } ] }
        ].freeze

        PUBLIC_INCLUDES = [
          :farm,
          :cultivation_plan_fields,
          { cultivation_plan_crops: CROP_WITH_STAGES },
          { field_cultivations: [ :cultivation_plan_field, :cultivation_plan_crop ] }
        ].freeze

        # @param plan_id [Integer, String]
        # @param user_id [Integer]
        # @return [::CultivationPlan]
        # @raise [ActiveRecord::RecordNotFound]
        def find_by_plan_id_and_user_id(plan_id:, user_id:)
          pid = plan_id.to_i
          user = ::User.find(user_id)
          ::CultivationPlan.plan_type_private.by_user(user).preload(PRIVATE_PRELOAD).find(pid)
        end

        # @param plan_id [Integer, String]
        # @return [::CultivationPlan] plan_type public のみ
        # @raise [ActiveRecord::RecordNotFound]
        def find_by_plan_id_public(plan_id:)
          pid = plan_id.to_i
          ::CultivationPlan.plan_type_public.includes(PUBLIC_INCLUDES).find(pid)
        end
      end
    end
  end
end
