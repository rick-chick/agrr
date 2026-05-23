# frozen_string_literal: true

module Adapters
  module CultivationPlan
    # add_crop での候補探索・adjust（CompositionRoot 経由でドメイン／ゲートウェイへ）。
    class RestAddCropOptimizationHostBridge
      def initialize(controller)
        @controller = controller
      end

      def attach_plan_for_candidates(plan)
        @plan = plan
      end

      def find_best_candidate_for_crop(crop, field_id, display_range:)
        CompositionRoot.find_best_add_crop_candidate_service.call(
          cultivation_plan: @plan,
          crop: crop,
          field_id: field_id,
          display_range: display_range,
          ui_filter_context: @controller.send(:ui_filter_context)
        )
      end

      def plan_allocation_adjust(plan, moves)
        CompositionRoot.plan_allocation_adjust_legacy(plan_id: plan.id, moves: moves)
      end
    end
  end
end
