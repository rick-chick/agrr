# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # agrr allocate に渡す入力まとめ（配列・ハッシュはアダプターが agrr CLI 形式へ変換）。
      class PlanAllocationInput
        attr_reader :fields, :crops, :weather_data, :planning_start, :planning_end,
                    :interaction_rules, :objective, :max_time, :enable_parallel

        def initialize(fields:, crops:, weather_data:, planning_start:, planning_end:,
                       interaction_rules: nil, objective: "maximize_profit", max_time: nil, enable_parallel: false)
          @fields = fields
          @crops = crops
          @weather_data = weather_data
          @planning_start = planning_start
          @planning_end = planning_end
          @interaction_rules = interaction_rules
          @objective = objective
          @max_time = max_time
          @enable_parallel = enable_parallel
        end
      end
    end
  end
end
