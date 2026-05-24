# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # エントリ作物スケジュール: AGRR `optimize period` の I/O のみ（Adapter 実装）。
      class EntryScheduleOptimizationGateway
        # @return [Hash] :start_date, :completion_date, :days, :gdd, :cost 等（Adapter が parse 済み）
        def optimize_period(
          crop_name:,
          crop_variety:,
          weather_data:,
          evaluation_start:,
          evaluation_end:,
          crop_requirement:,
          crop:
        )
          raise NotImplementedError, "Subclasses must implement optimize_period"
        end
      end
    end
  end
end
