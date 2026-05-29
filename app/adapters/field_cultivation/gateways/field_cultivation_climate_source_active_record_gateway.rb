# frozen_string_literal: true

module Adapters
  module FieldCultivation
    module Gateways
      # Implements `FieldCultivationClimateSourceGateway` and `FieldCultivationGateway`.
      class FieldCultivationClimateSourceActiveRecordGateway <
          Domain::FieldCultivation::Gateways::FieldCultivationClimateSourceGateway
        SnapshotMapper = Mappers::FieldCultivationClimateSourceSnapshotMapper
        ApiSummarySnapshotMapper = Mappers::FieldCultivationApiSummarySnapshotMapper
        ApiUpdateOutputSnapshotMapper = Mappers::FieldCultivationApiUpdateOutputSnapshotMapper

        def find_plan_access_snapshot_by_field_cultivation_id(field_cultivation_id)
          field_cultivation = load_field_cultivation!(field_cultivation_id)
          SnapshotMapper.plan_access_snapshot_from_model(field_cultivation)
        end

        def find_climate_source_snapshot_by_field_cultivation_id(field_cultivation_id)
          field_cultivation = load_field_cultivation!(field_cultivation_id)
          SnapshotMapper.climate_source_snapshot_from_model(field_cultivation)
        end

        def find_api_summary_by_field_cultivation_id(field_cultivation_id)
          field_cultivation = load_field_cultivation!(field_cultivation_id)
          ApiSummarySnapshotMapper.from_model(field_cultivation)
        end

        def find_weather_prediction_targets_by_plan_id(plan_id)
          plan = Adapters::CultivationPlan::Gateways::PlanFarmWeatherPreload.find!(plan_id: plan_id)
          Adapters::WeatherData::Mappers::WeatherPredictionTargetsMapper.from_plan(plan)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound
        end

        def update_field_cultivation_schedule(field_cultivation_id:, start_date:, completion_date:, cultivation_days: nil)
          fc = load_field_cultivation!(field_cultivation_id)
          attrs = { start_date: start_date, completion_date: completion_date }
          attrs[:cultivation_days] = cultivation_days unless cultivation_days.nil?
          unless fc.update(attrs)
            raise Domain::Shared::Exceptions::RecordInvalid.new(nil, errors: fc.errors.full_messages)
          end

          ApiUpdateOutputSnapshotMapper.from_model(fc)
        end

        private

        def load_field_cultivation!(field_cultivation_id)
          Gateways::FieldCultivationClimatePreload.find!(field_cultivation_id: field_cultivation_id)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound
        end
      end
    end
  end
end
