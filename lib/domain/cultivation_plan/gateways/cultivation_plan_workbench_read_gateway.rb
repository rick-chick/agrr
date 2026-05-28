# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # REST GET data: 計画ワークベンチ行の読取（永続のみ。結合は domain mapper）。
      class CultivationPlanWorkbenchReadGateway
        # @return [Domain::CultivationPlan::Dtos::CultivationPlanWorkbenchSnapshot]
        # @raise [Domain::Shared::Exceptions::RecordNotFound]
        def load_snapshot_by_plan_id_and_user_id(plan_id:, user_id:)
          raise NotImplementedError
        end

        # @return [Domain::CultivationPlan::Dtos::CultivationPlanWorkbenchSnapshot]
        # @raise [Domain::Shared::Exceptions::RecordNotFound]
        def load_snapshot_by_plan_id(plan_id:)
          raise NotImplementedError
        end
      end
    end
  end
end
