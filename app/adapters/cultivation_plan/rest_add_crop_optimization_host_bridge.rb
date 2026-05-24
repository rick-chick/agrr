# frozen_string_literal: true

module Adapters
  module CultivationPlan
    # add_crop: 計画の attach と adjust（候補探索は FindBestAddCropCandidateInteractor へ）。
    class RestAddCropOptimizationHostBridge < Domain::CultivationPlan::Ports::AddCropOptimizationHostPort
      def initialize(controller)
        @controller = controller
      end

      def attach_plan_for_candidates!(auth:, plan_id:)
        ::Adapters::CultivationPlan::Persistence::PlanScopes.find_record!(auth, plan_id)
      end

      def adjust_with_moves!(plan_id:, moves:)
        raw = CompositionRoot.plan_allocation_adjust_legacy(plan_id: plan_id, moves: moves)
        Domain::CultivationPlan::Dtos::AddCropAdjustResult.new(
          success: raw[:success] || raw["success"],
          message: raw[:message] || raw["message"],
          http_status: raw[:status] || raw["status"],
          skipped: raw[:skipped] || raw["skipped"]
        )
      end
    end
  end
end
