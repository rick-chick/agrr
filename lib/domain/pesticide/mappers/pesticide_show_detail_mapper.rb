# frozen_string_literal: true

module Domain
  module Pesticide
    module Mappers
      module PesticideShowDetailMapper
        module_function

        # @param snapshot [Dtos::PesticideShowDetailSnapshot]
        # @return [Domain::Pesticide::Dtos::PesticideDetailOutput]
        def from_snapshot(snapshot)
          Dtos::PesticideDetailOutput.new(
            pesticide: pesticide_entity_from_snapshot(snapshot.pesticide),
            crop_name: snapshot.crop_name,
            pest_name: snapshot.pest_name,
            usage_constraint_snapshot: usage_constraint_from_snapshot(snapshot.usage_constraint),
            application_detail_snapshot: application_detail_from_snapshot(snapshot.application_detail)
          )
        end

        def pesticide_entity_from_snapshot(wire)
          Entities::PesticideEntity.new(
            id: wire.id,
            user_id: wire.user_id,
            name: wire.name,
            active_ingredient: wire.active_ingredient,
            description: wire.description,
            crop_id: wire.crop_id,
            pest_id: wire.pest_id,
            region: wire.region,
            is_reference: wire.is_reference,
            created_at: wire.created_at,
            updated_at: wire.updated_at
          )
        end

        def usage_constraint_from_snapshot(wire)
          return nil unless wire

          Dtos::PesticideUsageConstraintSnapshot.new(
            min_temperature: wire.min_temperature,
            max_temperature: wire.max_temperature,
            max_wind_speed_m_s: wire.max_wind_speed_m_s,
            max_application_count: wire.max_application_count,
            harvest_interval_days: wire.harvest_interval_days,
            other_constraints: wire.other_constraints
          )
        end

        def application_detail_from_snapshot(wire)
          return nil unless wire

          Dtos::PesticideApplicationDetailSnapshot.new(
            dilution_ratio: wire.dilution_ratio,
            amount_per_m2: wire.amount_per_m2,
            amount_unit: wire.amount_unit,
            application_method: wire.application_method
          )
        end
      end
    end
  end
end
