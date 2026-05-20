# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # プライベート計画「最適化進捗」画面用。ActiveRecord は含めない。
      class PrivatePlanOptimizing
        attr_reader :id, :plan_year, :farm_display_name, :cultivation_plan_crops_count,
                    :optimization_phase_message, :status

        # @param id [Integer]
        # @param plan_year [Integer, nil]
        # @param farm_display_name [String]
        # @param cultivation_plan_crops_count [Integer]
        # @param optimization_phase_message [String, nil]
        # @param status [String] CultivationPlan#status（pending / optimizing / completed / failed）
        def initialize(id:, plan_year:, farm_display_name:, cultivation_plan_crops_count:,
                       optimization_phase_message:, status:)
          @id = id
          @plan_year = plan_year
          @farm_display_name = farm_display_name
          @cultivation_plan_crops_count = cultivation_plan_crops_count
          @optimization_phase_message = optimization_phase_message
          @status = status
        end

        def completed?
          status == "completed"
        end

        def failed?
          status == "failed"
        end
      end
    end
  end
end
