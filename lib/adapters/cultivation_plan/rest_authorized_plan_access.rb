# frozen_string_literal: true

module Adapters
  module CultivationPlan
    # REST 用: private / public それぞれのスコープで CultivationPlan を1件取得（認可はスコープに委譲）。
    # 戻りは永続モデル（フロー専用 Gateway 実装内でのみ使用し、Interactor へは渡さない）。
    module RestAuthorizedPlanAccess
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
      # @return [CultivationPlan]
      # @raise [ActiveRecord::RecordNotFound]
      def find!(auth, plan_id)
        pid = plan_id.to_i
        if auth.private?
          user = ::User.find(auth.user_id)
          ::PlanPolicy.private_scope(user).preload(PRIVATE_PRELOAD).find(pid)
        else
          ::PlanPolicy.public_scope.includes(PUBLIC_INCLUDES).find(pid)
        end
      end
    end
  end
end
