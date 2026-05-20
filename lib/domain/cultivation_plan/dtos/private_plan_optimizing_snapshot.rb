# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # 最適化進捗画面用のゲートウェイ読み取りスナップショット（Presenter 形の PageDto は組み立てない）
      class PrivatePlanOptimizingSnapshot
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
