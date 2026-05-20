# frozen_string_literal: true

module Adapters
  module Pesticide
    module Mappers
      # +Pesticide+ レコードから {Domain::Pesticide::Dtos::PesticideMasterFormSnapshot} を組み立てる。
      class PesticideMasterFormSnapshotMapper
        class << self
          # @param pesticide [::Pesticide]
          # @param error_messages [Array<String>]
          # @return [Domain::Pesticide::Dtos::PesticideMasterFormSnapshot]
          def from_record(pesticide, error_messages: [])
            Domain::Pesticide::Dtos::PesticideMasterFormSnapshot.new(
              id: pesticide.id,
              new_record: pesticide.new_record?,
              error_messages: Array(error_messages),
              name: pesticide.name,
              active_ingredient: pesticide.active_ingredient,
              description: pesticide.description,
              crop_id: pesticide.crop_id,
              pest_id: pesticide.pest_id,
              is_reference: pesticide.is_reference,
              region: pesticide.region,
              user_id: pesticide.user_id,
              pesticide_usage_constraint_attributes: usage_constraint_attrs(pesticide),
              pesticide_application_detail_attributes: application_detail_attrs(pesticide)
            )
          end

          private

          def usage_constraint_attrs(pesticide)
            constraint = pesticide.pesticide_usage_constraint
            if constraint
              {
                id: constraint.id,
                min_temperature: constraint.min_temperature,
                max_temperature: constraint.max_temperature,
                max_wind_speed_m_s: constraint.max_wind_speed_m_s,
                max_application_count: constraint.max_application_count,
                harvest_interval_days: constraint.harvest_interval_days,
                other_constraints: constraint.other_constraints,
                _destroy: false
              }
            else
              {
                id: nil,
                min_temperature: nil,
                max_temperature: nil,
                max_wind_speed_m_s: nil,
                max_application_count: nil,
                harvest_interval_days: nil,
                other_constraints: nil,
                _destroy: false
              }
            end
          end

          def application_detail_attrs(pesticide)
            detail = pesticide.pesticide_application_detail
            if detail
              {
                id: detail.id,
                dilution_ratio: detail.dilution_ratio,
                amount_per_m2: detail.amount_per_m2,
                amount_unit: detail.amount_unit,
                application_method: detail.application_method,
                _destroy: false
              }
            else
              {
                id: nil,
                dilution_ratio: nil,
                amount_per_m2: nil,
                amount_unit: nil,
                application_method: nil,
                _destroy: false
              }
            end
          end
        end
      end
    end
  end
end
