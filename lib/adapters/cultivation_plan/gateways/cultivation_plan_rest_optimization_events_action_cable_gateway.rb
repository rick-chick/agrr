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

        def broadcast_optimization_complete(plan:, status:)
          @logger.info "📡 [Action Cable] Broadcasting optimization #{status} for plan_id=#{plan.id}"

          channel_class = plan.plan_type_public? ? OptimizationChannel : PlansOptimizationChannel
          @logger.info "📡 [Action Cable] Using channel: #{channel_class.name}"

          channel_class.broadcast_to(
            plan,
            {
              status: status,
              message: I18n.t("optimization.messages.#{status}"),
              total_profit: plan.total_profit,
              total_revenue: plan.total_revenue,
              total_cost: plan.total_cost,
              field_cultivations_count: plan.field_cultivations.count
            }
          )

          @logger.info "✅ [Action Cable] Broadcast sent successfully"
        rescue Timeout::Error,
               IOError,
               SystemCallError,
               JSON::GeneratorError => e
          @logger.error "❌ [Action Cable] Broadcast failed for plan_id=#{plan.id}: #{e.class} - #{e.message}"
          @logger.error "Backtrace:\n#{e.backtrace.first(10).join("\n")}"
        end
      end
    end
  end
end
