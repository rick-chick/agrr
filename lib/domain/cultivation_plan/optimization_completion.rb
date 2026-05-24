# frozen_string_literal: true

module Domain
  module CultivationPlan
    # Shared gateway orchestration for marking a plan completed when all field cultivations are done.
    # Used by AdvanceCultivationPlanPhaseInteractor after phase updates.
    module OptimizationCompletion
      module_function

      # @param gateway [Domain::CultivationPlan::Gateways::CultivationPlanGateway]
      # @param plan_id [Integer]
      # @return [Entities::CultivationPlanEntity]
      def apply(gateway:, plan_id:)
        plan = gateway.find_by_id(plan_id)
        field_cultivations = gateway.list_by_plan_id(plan_id)
        statuses = field_cultivations.map(&:status)

        return plan unless Policies::CultivationPlanOptimizationCompletePolicy.should_mark_plan_completed?(
          plan_status: plan.status,
          field_cultivation_statuses: statuses
        )

        gateway.update(plan_id, { status: "completed" })
      end
    end
  end
end
