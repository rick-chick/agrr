# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # add_crop: plan_allocation_adjust 呼出しのみ（ホストブリッジ経由）。
      class CultivationPlanAddCropAdjustInvokeGateway
        def initialize(logger:)
          @logger = logger
        end

        # @return [Hash] adjust 結果ハッシュ（success キー等）
        def adjust_with_moves!(optimization_host:, plan_id:, moves:)
          raise NotImplementedError
        end

        protected

        attr_reader :logger
      end
    end
  end
end
