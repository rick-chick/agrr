# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # effective_planning_period 計算用の作付け期間スナップショット（読み取り専用）。
      class FieldCultivationPlanningPeriod
        attr_reader :start_date, :completion_date

        # @param start_date [Date, nil]
        # @param completion_date [Date, nil]
        def initialize(start_date:, completion_date:)
          @start_date = start_date
          @completion_date = completion_date
          freeze
        end
      end
    end
  end
end
