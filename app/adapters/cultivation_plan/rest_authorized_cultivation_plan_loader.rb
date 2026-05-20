# frozen_string_literal: true

module Adapters
  module CultivationPlan
    # REST 用: private / public それぞれの Relation で CultivationPlan を1件取得する。
    # 条件は `Domain::CultivationPlan::Policies::PlanAccess.private_scope` / `public_scope` と同義（本モジュールは `PlanAccess` を参照しない）。
    module RestAuthorizedCultivationPlanLoader
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
      # @return [::CultivationPlan]
      # @raise [ActiveRecord::RecordNotFound]
      def find!(auth, plan_id)
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
