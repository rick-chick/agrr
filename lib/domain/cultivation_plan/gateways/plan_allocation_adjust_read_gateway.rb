# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # plan_allocation_adjust 用: 計画の読取（AR はアダプター内に閉じる）。
      class PlanAllocationAdjustReadGateway
        # @param plan_id [Integer]
        # @return [Domain::CultivationPlan::Dtos::PlanAllocationAdjustReadSnapshot]
        def find_adjust_read_snapshot_by_plan_id(plan_id:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        # REST adjust（私有）: ユーザー所有の計画のみ。見つからなければ RecordNotFound。
        # @return [Domain::CultivationPlan::Dtos::PlanAllocationAdjustReadSnapshot]
        def find_adjust_read_snapshot_by_plan_id_and_user_id(plan_id:, user_id:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        # REST adjust（公開）: plan_type public のみ。
        # @return [Domain::CultivationPlan::Dtos::PlanAllocationAdjustReadSnapshot]
        def find_adjust_read_snapshot_by_plan_id_public(plan_id:)
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
