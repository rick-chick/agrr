# frozen_string_literal: true

module Adapters
  module CultivationPlan
    # ActionCable 購読直後に DB 上の最適化状態を 1 回送る（進捗は tokio broadcast / 接続前 broadcast を取りこぼすため）。
    module OptimizationSubscriptionSnapshot
      module_function

      # @param cultivation_plan [CultivationPlan]
      # @return [Hash, nil] OptimizationChannel / PlansOptimizationChannel の transmit 引数
      def payload_for(cultivation_plan)
        if cultivation_plan.status_completed?
          return { status: "completed", progress: 100 }
        end

        if cultivation_plan.status_failed?
          message = cultivation_plan.optimization_phase_message
          return {
            status: "failed",
            progress: 0,
            phase: cultivation_plan.optimization_phase,
            phase_message: message,
            message: message
          }
        end

        return nil unless cultivation_plan.status_optimizing?

        plan_entity = entity_from_record(cultivation_plan)
        progress = Domain::CultivationPlan::Calculators::CultivationPlanOptimizationProgressCalculator.progress_percent(
          field_cultivations: cultivation_plan.field_cultivations
        )
        Domain::CultivationPlan::Mappers::CultivationPlanPhaseBroadcastPayloadMapper.to_port_payload(
          plan: plan_entity,
          progress: progress,
          phase_message: cultivation_plan.optimization_phase_message
        )
      end

      def entity_from_record(cultivation_plan)
        Domain::CultivationPlan::Entities::CultivationPlanEntity.new(
          id: cultivation_plan.id,
          farm_id: cultivation_plan.farm_id,
          user_id: cultivation_plan.user_id,
          total_area: cultivation_plan.total_area,
          plan_type: cultivation_plan.plan_type,
          plan_year: cultivation_plan.plan_year,
          plan_name: cultivation_plan.plan_name,
          planning_start_date: cultivation_plan.planning_start_date,
          planning_end_date: cultivation_plan.planning_end_date,
          status: cultivation_plan.status,
          session_id: cultivation_plan.session_id,
          optimization_phase: cultivation_plan.optimization_phase,
          optimization_phase_message: cultivation_plan.optimization_phase_message
        )
      end
      private_class_method :entity_from_record
    end
  end
end
