# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      class PlanSaveFertilizeAttributesMapper
        # @param row [Dtos::PublicPlanSaveFertilizeReferenceRow]
        # @param region [String, nil] farm region fallback
        # @param name [String] resolved unique display name
        # @return [Hash]
        def self.attributes_for_create(row:, region:, name:)
          {
            name: name,
            n: row.n,
            p: row.p,
            k: row.k,
            description: row.description,
            package_size: row.package_size,
            region: row.region || region,
            is_reference: false,
            source_fertilize_id: row.reference_fertilize_id
          }
        end
      end
    end
  end
end
