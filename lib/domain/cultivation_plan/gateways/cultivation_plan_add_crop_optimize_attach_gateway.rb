# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # add_crop: 候補探索用に計画を optimization_host へ結び付け（永続読取のみ）。
      class CultivationPlanAddCropOptimizeAttachGateway
        def initialize(logger:)
          @logger = logger
        end

        # @param optimization_host [#attach_plan_for_candidates]
        # @return [Hash] :success | :not_found | :record_invalid | :unexpected
        def attach_plan!(auth:, plan_id:, optimization_host:)
          raise NotImplementedError
        end

        protected

        attr_reader :logger
      end
    end
  end
end
