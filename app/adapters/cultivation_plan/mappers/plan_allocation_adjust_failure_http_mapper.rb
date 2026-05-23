# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Mappers
      class PlanAllocationAdjustFailureHttpMapper
        Failure = Domain::CultivationPlan::Dtos::PlanAllocationAdjustFailure

        def self.http_status_for(kind)
          case kind
          when Failure::KIND_NO_WEATHER_LOCATION, Failure::KIND_NOT_FOUND
            :not_found
          when Failure::KIND_INVALID_DATE, Failure::KIND_CROP_MISSING_GROWTH_STAGES
            :bad_request
          when Failure::KIND_CALCULATE_PERIOD_FAILED,
               Failure::KIND_WEATHER_FETCH_FAILED,
               Failure::KIND_ADJUST_EXECUTION_FAILED,
               Failure::KIND_RESULT_EMPTY,
               Failure::KIND_UNEXPECTED
            :internal_server_error
          else
            :internal_server_error
          end
        end
      end
    end
  end
end
