# frozen_string_literal: true

module Adapters
  module CultivationPlan
    # PublicPlansController の計画解決（find_by + missing）、RecordNotFound をハッシュに正規化しない版
    module ManageablePublicPlanLookup
      module_function

      # @return [Hash] :missing_plan_id | :not_found | :ok + plan
      def call(plan_id:, scope:, includes: nil)
        return { kind: :missing_plan_id } if plan_id.blank?

        rel = includes ? scope.includes(includes) : scope
        plan = rel.find_by(id: plan_id)
        return { kind: :not_found } unless plan

        { kind: :ok, plan: plan }
      end
    end
  end
end
