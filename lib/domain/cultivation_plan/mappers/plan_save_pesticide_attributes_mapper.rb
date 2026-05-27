# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      class PlanSavePesticideAttributesMapper
        # @param row [Dtos::PublicPlanSavePesticideReferenceRow]
        # @param region [String, nil] farm region fallback
        # @param user_crop_id [Integer]
        # @param user_pest_id [Integer]
        # @return [Hash]
        def self.attributes_for_create(row:, region:, user_crop_id:, user_pest_id:)
          {
            crop_id: user_crop_id,
            pest_id: user_pest_id,
            name: row.name,
            active_ingredient: row.active_ingredient,
            description: row.description,
            region: row.region || region,
            is_reference: false,
            source_pesticide_id: row.reference_pesticide_id
          }
        end

        # @param row [Dtos::PublicPlanSavePesticideReferenceRow]
        # @return [Hash, nil]
        def self.usage_constraint_attributes(row:)
          constraint = row.usage_constraint
          return nil unless constraint

          {
            min_temperature: constraint.min_temperature,
            max_temperature: constraint.max_temperature,
            max_wind_speed_m_s: constraint.max_wind_speed_m_s,
            max_application_count: constraint.max_application_count,
            harvest_interval_days: constraint.harvest_interval_days,
            other_constraints: constraint.other_constraints
          }
        end

        # @param row [Dtos::PublicPlanSavePesticideReferenceRow]
        # @return [Hash, nil]
        def self.application_detail_attributes(row:)
          detail = row.application_detail
          return nil unless detail

          {
            dilution_ratio: detail.dilution_ratio,
            amount_per_m2: detail.amount_per_m2,
            amount_unit: detail.amount_unit,
            application_method: detail.application_method
          }
        end
      end
    end
  end
end
