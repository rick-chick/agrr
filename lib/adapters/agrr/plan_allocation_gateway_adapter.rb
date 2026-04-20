# frozen_string_literal: true

module Adapters
  module Agrr
    # Domain 層から agrr 多圃場割当 CLI（Agrr::AllocationGateway）を呼ぶ薄いアダプタ。
    # 最適化ロジックは allocate サブコマンド（T-031 / OptimizationGateway 統合の一環）。
    class PlanAllocationGatewayAdapter
      def initialize(implementation = ::Agrr::AllocationGateway.new)
        @implementation = implementation
      end

      def allocate(fields:, crops:, weather_data:, planning_start:, planning_end:, interaction_rules: nil, objective: "maximize_profit", max_time: nil, enable_parallel: false)
        @implementation.allocate(
          fields: fields,
          crops: crops,
          weather_data: weather_data,
          planning_start: planning_start,
          planning_end: planning_end,
          interaction_rules: interaction_rules,
          objective: objective,
          max_time: max_time,
          enable_parallel: enable_parallel
        )
      end
    end
  end
end
