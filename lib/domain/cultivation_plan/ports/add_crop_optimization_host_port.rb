# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Ports
      # add_crop: 候補探索・adjust のエッジブリッジ（AR 読取・CompositionRoot 配線は adapter）。
      class AddCropOptimizationHostPort
        # @param user_id [Integer, nil] 指定時は private 計画を user スコープで narrow find
        # @raise [Domain::Shared::Exceptions::RecordNotFound]
        def attach_plan_for_candidates!(plan_id:, user_id: nil)
          raise NotImplementedError
        end

        # @return [Domain::CultivationPlan::Dtos::AddCropAdjustResult]
        def adjust_with_moves!(plan_id:, moves:)
          raise NotImplementedError
        end
      end
    end
  end
end
