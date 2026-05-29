# frozen_string_literal: true

module Adapters
  module FieldCultivation
    module Mappers
      # ActiveRecord → api summary wire（業務判断なし。gdd キー抽出のみ）。
      module FieldCultivationApiSummaryWireMapper
        Wire = Data.define(
          :id,
          :field_name,
          :crop_name,
          :area,
          :start_date,
          :completion_date,
          :cultivation_days,
          :estimated_cost,
          :gdd,
          :status
        )

        module_function

        # @param field_cultivation [FieldCultivation]
        # @return [Wire]
        def from_model(field_cultivation)
          Wire.new(
            id: field_cultivation.id,
            field_name: field_cultivation.field_display_name,
            crop_name: field_cultivation.crop_display_name,
            area: field_cultivation.area,
            start_date: field_cultivation.start_date,
            completion_date: field_cultivation.completion_date,
            cultivation_days: field_cultivation.cultivation_days,
            estimated_cost: field_cultivation.estimated_cost,
            gdd: field_cultivation.optimization_result&.dig("raw", "total_gdd"),
            status: field_cultivation.status
          )
        end
      end
    end
  end
end
