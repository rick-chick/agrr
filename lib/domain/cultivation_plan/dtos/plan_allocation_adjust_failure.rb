# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # plan_allocation_adjust の失敗区分（Presenter / adapter が HTTP を決める）。
      class PlanAllocationAdjustFailure
        KIND_NO_WEATHER_LOCATION = :no_weather_location
        KIND_INVALID_DATE = :invalid_date
        KIND_CALCULATE_PERIOD_FAILED = :calculate_period_failed
        KIND_WEATHER_FETCH_FAILED = :weather_fetch_failed
        KIND_ADJUST_EXECUTION_FAILED = :adjust_execution_failed
        KIND_RESULT_EMPTY = :result_empty
        KIND_CROP_MISSING_GROWTH_STAGES = :crop_missing_growth_stages
        KIND_NOT_FOUND = :not_found
        KIND_UNEXPECTED = :unexpected

        attr_reader :kind, :message

        # @param kind [Symbol] one of KIND_* constants
        # @param message [String]
        def initialize(kind:, message:)
          @kind = kind
          @message = message
        end
      end
    end
  end
end
