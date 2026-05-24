# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Persistence
      # REST 栽培計画の AR Relation / preload。認可判断は Interactor + PlanReadAuthorization。
      module PlanScopes
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

        # @param auth [Domain::CultivationPlan::Dtos::CultivationPlanRestAuth]
        # @param plan_id [Integer, String]
        # @return [::CultivationPlan]
        # @raise [ActiveRecord::RecordNotFound]
        def find_record!(auth, plan_id)
          pid = plan_id.to_i
          if auth.private?
            user = ::User.find(auth.user_id)
            ::CultivationPlan.plan_type_private.by_user(user).preload(PRIVATE_PRELOAD).find(pid)
          else
            ::CultivationPlan.plan_type_public.includes(PUBLIC_INCLUDES).find(pid)
          end
        end
      end
    end
  end
end
