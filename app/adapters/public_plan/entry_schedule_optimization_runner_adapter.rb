# frozen_string_literal: true

module Adapters
  module PublicPlan
    # EntryScheduleOptimizeInteractor へ委譲（PublicPlan Interactor から具象名を隠す）
    class EntryScheduleOptimizationRunnerAdapter
      def self.call(crop:, weather_payload:, farm:, crop_gateway:)
        CompositionRoot.entry_schedule_optimize_interactor(
          crop: crop,
          weather_payload: weather_payload,
          farm: farm,
          crop_gateway: crop_gateway
        ).call
      end
    end
  end
end
