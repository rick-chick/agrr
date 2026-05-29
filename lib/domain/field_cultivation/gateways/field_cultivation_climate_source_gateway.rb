# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Gateways
      # Narrow read I/O for climate data (plan access + climate source + weather targets).
      class FieldCultivationClimateSourceGateway
        # @return [Domain::FieldCultivation::Dtos::FieldCultivationPlanAccessSnapshot]
        # @raise [Domain::Shared::Exceptions::RecordNotFound]
        def find_plan_access_snapshot_by_field_cultivation_id(field_cultivation_id)
          raise NotImplementedError,
                "Subclasses must implement find_plan_access_snapshot_by_field_cultivation_id"
        end

        # @return [Domain::FieldCultivation::Dtos::FieldCultivationClimateSourceSnapshot]
        # @raise [Domain::Shared::Exceptions::RecordNotFound]
        def find_climate_source_snapshot_by_field_cultivation_id(field_cultivation_id)
          raise NotImplementedError,
                "Subclasses must implement find_climate_source_snapshot_by_field_cultivation_id"
        end

        # @return [Domain::WeatherData::Dtos::WeatherPredictionTargets]
        def find_weather_prediction_targets_by_plan_id(plan_id)
          raise NotImplementedError
        end
      end
    end
  end
end
