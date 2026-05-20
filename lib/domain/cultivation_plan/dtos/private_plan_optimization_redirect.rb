# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # 私有計画「最適化へ進む」遷移に必要な読み取り値のみ（ActiveRecord は含めない）。
      class PrivatePlanOptimizationRedirect
        attr_reader :plan_id, :already_optimizing

        def initialize(plan_id:, already_optimizing:)
          @plan_id = plan_id
          @already_optimizing = already_optimizing
        end
      end
    end
  end
end
