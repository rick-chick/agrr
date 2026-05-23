# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # ワークベンチ読取のドメインスナップショット（Presenter 向け JSON はマッパーで組み立て）。
      class CultivationPlanWorkbenchSnapshot
        attr_reader :plan, :fields, :crops, :cultivations, :available_crop_rows

        def initialize(plan:, fields:, crops:, cultivations:, available_crop_rows:)
          @plan = plan
          @fields = fields
          @crops = crops
          @cultivations = cultivations
          @available_crop_rows = available_crop_rows
          freeze
        end
      end
    end
  end
end
