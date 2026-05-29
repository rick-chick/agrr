# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # plan_allocation_adjust 用: 計画の読取（AR はアダプター内に閉じる）。
      class PlanAllocationAdjustReadGateway
        # @param plan_id [Integer]
        # @return [Dtos::PlanAllocationAdjustReadPlanHeaderSnapshot]
        def find_adjust_plan_header_snapshot_by_plan_id(plan_id:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        # @param plan_id [Integer]
        # @return [Array<Dtos::PlanAllocationAdjustReadPlanFieldRowSnapshot>]
        def list_adjust_plan_field_rows_by_plan_id(plan_id:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        # @param plan_id [Integer]
        # @return [Array<Dtos::PlanAllocationAdjustReadFieldCultivationRowSnapshot>]
        def list_adjust_field_cultivation_rows_by_plan_id(plan_id:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        # @param plan_id [Integer]
        # @return [Array<Dtos::PlanAllocationAdjustReadPlanCropRowSnapshot>]
        def list_adjust_plan_crop_rows_by_plan_id(plan_id:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        # @param weather_location_id [Integer, nil]
        # @return [Array<Domain::WeatherData::Dtos::HistoricalWeatherObservation>]
        def list_historical_weather_rows(weather_location_id:, historical_start:, historical_end:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        # @return [Hash] :id, :field_cultivations_count
        def plan_summary_for_adjust_response(plan_id:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end
      end
    end
  end
end
