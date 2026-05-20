# frozen_string_literal: true

module Adapters
  module PublicPlans
    # EntryScheduleOptimization の Agrr 実装へ委譲（Interactor から具象 Adapter 名を隠す）
    class EntryScheduleOptimizationRunnerAdapter
      def self.call(crop:, weather_payload:, farm:, crop_gateway:)
        Adapters::Agrr::Gateways::EntryScheduleOptimizationDaemonGateway.call(
          crop: crop,
          weather_payload: weather_payload,
          farm: farm,
          crop_gateway: crop_gateway
        )
      end
    end
  end
end
