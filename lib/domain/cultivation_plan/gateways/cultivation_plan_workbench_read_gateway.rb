# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # REST GET data: 計画ワークベンチ行の読取（永続のみ。結合は domain mapper）。
      class CultivationPlanWorkbenchReadGateway
        # @return [Object] CultivationPlanRestPlanSnapshot（`CultivationPlanRestPlanSnapshotMapper` の戻り）
        # @raise [Domain::Shared::Exceptions::RecordNotFound]
        def load_rest_plan_snapshot_by_plan_id(plan_id:)
          raise NotImplementedError
        end
      end
    end
  end
end
