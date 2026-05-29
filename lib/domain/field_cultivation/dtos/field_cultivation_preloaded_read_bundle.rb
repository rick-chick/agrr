# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Dtos
      # Single preload の結果（plan access + climate source + API summary）。
      class FieldCultivationPreloadedReadBundle
        attr_reader :plan_access_snapshot, :climate_source_snapshot, :api_summary

        def initialize(plan_access_snapshot:, climate_source_snapshot:, api_summary:)
          @plan_access_snapshot = plan_access_snapshot
          @climate_source_snapshot = climate_source_snapshot
          @api_summary = api_summary
        end
      end
    end
  end
end
