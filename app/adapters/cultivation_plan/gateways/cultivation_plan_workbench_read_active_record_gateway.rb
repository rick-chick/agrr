# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class CultivationPlanWorkbenchReadActiveRecordGateway <
          Domain::CultivationPlan::Gateways::CultivationPlanWorkbenchReadGateway
        def load_rest_plan_snapshot_by_plan_id(plan_id:)
          plan = CultivationPlanRestPlanPreload.find_by_plan_id(plan_id: plan_id)
          Mappers::CultivationPlanRestPlanSnapshotMapper.from_cultivation_plan(plan)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end
      end
    end
  end
end
