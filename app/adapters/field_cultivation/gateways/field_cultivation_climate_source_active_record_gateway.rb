# frozen_string_literal: true

module Adapters
  module FieldCultivation
    module Gateways
      class FieldCultivationClimateSourceActiveRecordGateway <
          Domain::FieldCultivation::Gateways::FieldCultivationClimateSourceGateway
        SnapshotMapper = Mappers::FieldCultivationClimateSourceSnapshotMapper
        ApiSummaryWireMapper = Mappers::FieldCultivationApiSummaryWireMapper
        ApiUpdateOutputWireMapper = Mappers::FieldCultivationApiUpdateOutputWireMapper

        def find_plan_access_snapshot_by_field_cultivation_id(field_cultivation_id)
          fc = find_field_cultivation_model!(field_cultivation_id)
          SnapshotMapper.plan_access_snapshot_from_model(fc)
        end

        def find_climate_source_snapshot_by_field_cultivation_id(field_cultivation_id)
          field_cultivation = find_field_cultivation_model!(field_cultivation_id)
          SnapshotMapper.climate_source_snapshot_from_model(field_cultivation)
        end

        def find_weather_prediction_targets_by_plan_id(plan_id)
          plan = ::CultivationPlan.includes(farm: :weather_location).find(plan_id)
          farm = plan.farm
          Domain::WeatherData::Dtos::WeatherPredictionTargets.new(
            weather_location: Adapters::WeatherData::Mappers::WeatherLocationMapper.weather_location_dto_from_record(farm.weather_location),
            farm: Adapters::WeatherData::Mappers::FarmWeatherPredictionMapper.farm_weather_prediction_dto_from_record(farm)
          )
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound
        end

        def find_api_summary(field_cultivation_id:)
          fc = find_field_cultivation_model!(field_cultivation_id)
          wire = ApiSummaryWireMapper.from_model(fc)
          Domain::FieldCultivation::Mappers::FieldCultivationApiSummaryMapper.from_wire(wire)
        end

        def update_field_cultivation_schedule(field_cultivation_id:, start_date:, completion_date:, cultivation_days: nil)
          fc = find_field_cultivation_model!(field_cultivation_id)
          attrs = { start_date: start_date, completion_date: completion_date }
          attrs[:cultivation_days] = cultivation_days unless cultivation_days.nil?
          unless fc.update(attrs)
            raise Domain::Shared::Exceptions::RecordInvalid.new(nil, errors: fc.errors.full_messages)
          end

          wire = ApiUpdateOutputWireMapper.from_model(fc)
          Domain::FieldCultivation::Mappers::FieldCultivationApiUpdateOutputMapper.from_wire(wire)
        end

        private

        def find_field_cultivation_model!(field_cultivation_id)
          ::FieldCultivation.find(field_cultivation_id)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound
        end
      end
    end
  end
end
