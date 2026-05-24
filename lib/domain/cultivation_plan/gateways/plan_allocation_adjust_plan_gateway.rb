# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # plan_allocation_adjust 用: セッション内の CultivationPlan（AR はアダプター内に閉じる）へのアクセス。
      class PlanAllocationAdjustPlanGateway
        def begin_adjust_session!(plan_id)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        def end_adjust_session!
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        # @param exclude_ids [Array<Integer>]
        # @return [Hash] Agrr current allocation（daemon 投入用 JSON 互換）
        def build_current_allocation(exclude_ids: [])
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        def build_fields_config
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        def build_crops_config
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        def build_interaction_rules
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        # @return [Boolean] true のとき農場に WeatherLocation が無い
        def farm_without_weather_location?
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        # @return [Array<Domain::CultivationPlan::Dtos::FieldCultivationPlanningPeriod>]
        def list_field_cultivation_planning_periods
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        # @return [Domain::CultivationPlan::Dtos::PlanAllocationAdjustPlanningBoundaries]
        def planning_period_boundaries
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        def find_by_id
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        # @return [Domain::WeatherData::Dtos::CultivationPlanWeather]
        def cultivation_plan_weather_dto
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        # @return [Hash] :weather_location, :farm — WeatherPredictionInteractor / CompositionRoot にそのまま渡す
        def weather_prediction_association_records
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        # @return [Array<Hash>] 気象ロケーションの実測行（キーはシンボル混在可）
        def historical_weather_rows(historical_start:, historical_end:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        # @return [Hash] latitude, longitude, elevation, timezone（Merger 用）
        def weather_location_facts
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
