# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # 公開計画「最適化進捗」HTML 用のゲートウェイ読み取りスナップショット
      class PublicPlanOptimizingReadModel
        attr_reader :id, :plan_year, :farm_display_name, :cultivation_plan_crops_count,
                    :optimization_phase_message, :status

        def initialize(id:, plan_year:, farm_display_name:, cultivation_plan_crops_count:,
                       optimization_phase_message:, status:)
          @id = id
          @plan_year = plan_year
          @farm_display_name = farm_display_name
          @cultivation_plan_crops_count = cultivation_plan_crops_count
          @optimization_phase_message = optimization_phase_message
          @status = status
        end
      end
    end
  end
end
