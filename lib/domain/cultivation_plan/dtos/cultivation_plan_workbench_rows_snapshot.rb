# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # ワークベンチ行スナップショット（available_crop_rows 以外）。Mapper で最終 Snapshot に結合。
      class CultivationPlanWorkbenchRowsSnapshot
        attr_reader :plan, :fields, :crops, :cultivations, :farm_region

        def initialize(plan:, fields:, crops:, cultivations:, farm_region:)
          @plan = plan
          @fields = fields
          @crops = crops
          @cultivations = cultivations
          @farm_region = farm_region
          freeze
        end
      end
    end
  end
end
