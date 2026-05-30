# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # PublicPlanSaveInteractor 成功時に output port へ渡すメタデータ。
      class PublicPlanSaveSuccess
        attr_reader :cultivation_plan_id, :plan_reused

        # @param cultivation_plan_id [Integer, nil]
        # @param plan_reused [Boolean]
        def initialize(cultivation_plan_id:, plan_reused:)
          @cultivation_plan_id = cultivation_plan_id
          @plan_reused = plan_reused
          freeze
        end
      end
    end
  end
end
