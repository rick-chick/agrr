# frozen_string_literal: true

module Adapters
  module Pesticide
    module Mappers
      class PesticideMapper
        def self.pesticide_entity_from_record(record)
          Domain::Pesticide::Entities::PesticideEntity.new(
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

        def self.detail_output_dto_from_record(record)
          usage_snapshot =
            if record.pesticide_usage_constraint
              c = record.pesticide_usage_constraint
              Domain::Pesticide::Dtos::PesticideUsageConstraintSnapshot.new(
                min_temperature: c.min_temperature,
                max_temperature: c.max_temperature,
                max_wind_speed_m_s: c.max_wind_speed_m_s,
                max_application_count: c.max_application_count,
                harvest_interval_days: c.harvest_interval_days,
                other_constraints: c.other_constraints
              )
            end

          app_snapshot =
            if record.pesticide_application_detail
              d = record.pesticide_application_detail
              Domain::Pesticide::Dtos::PesticideApplicationDetailSnapshot.new(
                dilution_ratio: d.dilution_ratio,
                amount_per_m2: d.amount_per_m2,
                amount_unit: d.amount_unit,
                application_method: d.application_method
              )
            end

          Domain::Pesticide::Dtos::PesticideDetailOutput.new(
            pesticide: pesticide_entity_from_record(record),
            crop_name: record.crop&.name,
            pest_name: record.pest&.name,
            usage_constraint_snapshot: usage_snapshot,
            application_detail_snapshot: app_snapshot
          )
        end
      end
    end
  end
end
