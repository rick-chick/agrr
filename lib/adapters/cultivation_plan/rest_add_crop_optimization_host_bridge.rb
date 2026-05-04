# frozen_string_literal: true

module Adapters
  module CultivationPlan
    # add_crop での候補探索・adjust（AgrrOptimization をエッジから呼ぶ）。
    class RestAddCropOptimizationHostBridge
      def initialize(controller)
        @controller = controller
      end

      def attach_plan_for_candidates(plan)
        @controller.instance_variable_set(:@cultivation_plan, plan)
      end

      def find_best_candidate_for_crop(crop, field_id, display_range:)
        @controller.send(:find_best_candidate_for_crop, crop, field_id, display_range: display_range)
      end

      def adjust_with_db_weather(plan, moves)
        @controller.adjust_with_db_weather(plan, moves)
      end
    end
  end
end
