# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      class PlanSavePestAttributesMapper
        # @param row [Dtos::PublicPlanSavePestReferenceRow]
        # @param region [String, nil] farm region fallback
        # @return [Hash]
        def self.attributes_for_create(row:, region:)
          {
            name: row.name,
            name_scientific: row.name_scientific,
            family: row.family,
            order: row.order,
            description: row.description,
            occurrence_season: row.occurrence_season,
            region: row.region || region,
            is_reference: false,
            source_pest_id: row.reference_pest_id
          }
        end
      end
    end
  end
end
