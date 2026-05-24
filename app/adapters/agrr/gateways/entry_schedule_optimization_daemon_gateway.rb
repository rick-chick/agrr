# frozen_string_literal: true

module Adapters
  module Agrr
    module Gateways
      # エントリ作物スケジュール: AGRR CLI `optimize period` の I/O のみ。
      class EntryScheduleOptimizationDaemonGateway < Domain::CultivationPlan::Gateways::EntryScheduleOptimizationGateway
        def optimize_period(
          crop_name:,
          crop_variety:,
          weather_data:,
          evaluation_start:,
          evaluation_end:,
          crop_requirement:,
          crop:
        )
          ::Adapters::Agrr::Gateways::OptimizationDaemonGateway.new.optimize(
            crop_name: crop_name,
            crop_variety: crop_variety,
            weather_data: weather_data,
            field_area: 1.0,
            daily_fixed_cost: 0.01,
            evaluation_start: evaluation_start,
            evaluation_end: evaluation_end,
            crop_requirement: crop_requirement,
            crop: crop
          )
        rescue ::Adapters::Agrr::Gateways::DaemonClient::DaemonNotRunningError => e
          raise Domain::CultivationPlan::Errors::EntryScheduleOptimizationError.new(:daemon_unavailable, e.message)
        rescue ::Adapters::Agrr::Gateways::BaseGatewayV2::ExecutionError,
               ::Adapters::Agrr::Gateways::DaemonClient::CommandExecutionError => e
          raise Domain::CultivationPlan::Errors::EntryScheduleOptimizationError.new(:execution_failed, e.message)
        rescue ::Adapters::Agrr::Gateways::BaseGatewayV2::ParseError, JSON::ParserError => e
          raise Domain::CultivationPlan::Errors::EntryScheduleOptimizationError.new(:invalid_response, e.message)
        end
      end
    end
  end
end
