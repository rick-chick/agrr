# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class CultivationPlanRestOptimizationEventsActionCableGateway <
          Domain::CultivationPlan::Gateways::CultivationPlanRestOptimizationEventsGateway
        def initialize(logger:)
          @logger = logger
        end

        def broadcast_field_added(plan:, field_payload:, total_area:)
          channel_class = plan.plan_type == "private" ? PlansOptimizationChannel : OptimizationChannel
          channel_class.broadcast_to(
            plan,
            {
              type: "field_added",
              field: field_payload,
              total_area: total_area
            }
          )
        rescue ActiveRecord::RecordInvalid => e
          @logger.error "❌ [Action Cable field_added] plan_id=#{plan&.id} (validation): #{e.message}"
        rescue StandardError => e
          @logger.error "❌ [Action Cable field_added] plan_id=#{plan&.id}: #{e.message}"
        end

        def broadcast_field_removed(plan:, field_id:, total_area:)
          channel_class = plan.plan_type == "private" ? PlansOptimizationChannel : OptimizationChannel
          channel_class.broadcast_to(
            plan,
            {
              type: "field_removed",
              field_id: field_id,
              total_area: total_area
            }
          )
        rescue ActiveRecord::RecordInvalid => e
          @logger.error "❌ [Action Cable field_removed] plan_id=#{plan&.id} (validation): #{e.message}"
        rescue StandardError => e
          @logger.error "❌ [Action Cable field_removed] plan_id=#{plan&.id}: #{e.message}"
        end
      end
    end
  end
end
