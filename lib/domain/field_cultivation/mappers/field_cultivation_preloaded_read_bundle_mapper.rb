# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Mappers
      module FieldCultivationPreloadedReadBundleMapper
        module_function

        # @param plan_access_snapshot [Domain::FieldCultivation::Dtos::FieldCultivationPlanAccessSnapshot]
        # @param climate_source_snapshot [Domain::FieldCultivation::Dtos::FieldCultivationClimateSourceSnapshot]
        # @param api_summary [Domain::FieldCultivation::Dtos::FieldCultivationApiSummary]
        # @return [Domain::FieldCultivation::Dtos::FieldCultivationPreloadedReadBundle]
        def from_snapshots(plan_access_snapshot:, climate_source_snapshot:, api_summary:)
          Dtos::FieldCultivationPreloadedReadBundle.new(
            plan_access_snapshot: plan_access_snapshot,
            climate_source_snapshot: climate_source_snapshot,
            api_summary: api_summary
          )
        end
      end
    end
  end
end
