# frozen_string_literal: true

module Adapters
  module FieldCultivation
    module Mappers
      # ActiveRecord → api schedule update wire（業務判断なし）。
      module FieldCultivationApiUpdateOutputWireMapper
        Wire = Data.define(
          :field_cultivation_id,
          :start_date,
          :completion_date,
          :cultivation_days
        )

        module_function

        # @param field_cultivation [FieldCultivation]
        # @return [Wire]
        def from_model(field_cultivation)
          Wire.new(
            field_cultivation_id: field_cultivation.id,
            start_date: field_cultivation.start_date,
            completion_date: field_cultivation.completion_date,
            cultivation_days: field_cultivation.cultivation_days
          )
        end
      end
    end
  end
end
