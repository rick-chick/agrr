# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # REST add_crop: 作物追加→候補→adjust を1系統にまとめる（永続化・候補探索は実装側で担当）。
      class CultivationPlanAddCropCoordinatorGateway
        def initialize(logger:)
          @logger = logger
        end

        def run(auth:, plan_id:, crop_id:, field_id:, display_range:, crop_resolver:)
          raise NotImplementedError
        end

        protected

        attr_reader :logger
      end
    end
  end
end
