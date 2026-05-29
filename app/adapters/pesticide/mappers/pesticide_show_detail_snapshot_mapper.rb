# frozen_string_literal: true

module Adapters
  module Pesticide
    module Mappers
      module PesticideShowDetailSnapshotMapper
        Dtos = Domain::Pesticide::Dtos

        module_function

        def from_model(record)
          Dtos::PesticideShowDetailSnapshot.new(
            pesticide: pesticide_snapshot_from(record),
            crop_name: record.crop&.name,
            pest_name: record.pest&.name,
            usage_constraint: usage_constraint_snapshot_from(record.pesticide_usage_constraint),
            application_detail: application_detail_snapshot_from(record.pesticide_application_detail)
          )
        end

        def pesticide_snapshot_from(record)
          Dtos::PesticideShowDetailPesticideSnapshot.new(
            id: record.id,
            user_id: record.user_id,
            name: record.name,
            active_ingredient: record.active_ingredient,
            description: record.description,
            crop_id: record.crop_id,
            pest_id: record.pest_id,
            region: record.region,
            is_reference: record.is_reference,
            created_at: record.created_at,
            updated_at: record.updated_at
          )
        end

        def usage_constraint_snapshot_from(record)
          return nil unless record

          Domain::Pesticide::Dtos::PesticideUsageConstraintSnapshot.new(
            min_temperature: record.min_temperature,
            max_temperature: record.max_temperature,
            max_wind_speed_m_s: record.max_wind_speed_m_s,
            max_application_count: record.max_application_count,
            harvest_interval_days: record.harvest_interval_days,
            other_constraints: record.other_constraints
          )
        end

        def application_detail_snapshot_from(record)
          return nil unless record

          Domain::Pesticide::Dtos::PesticideApplicationDetailSnapshot.new(
            dilution_ratio: record.dilution_ratio,
            amount_per_m2: record.amount_per_m2,
            amount_unit: record.amount_unit,
            application_method: record.application_method
          )
        end
      end
    end
  end
end
