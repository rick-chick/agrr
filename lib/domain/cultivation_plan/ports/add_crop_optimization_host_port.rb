# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Ports
      # add_crop: 候補探索・adjust のエッジブリッジ（AR 読取・CompositionRoot 配線は adapter）。
      class AddCropOptimizationHostPort
        # @raise [Domain::Shared::Exceptions::RecordNotFound]
        def attach_plan_for_candidates!(auth:, plan_id:)
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
