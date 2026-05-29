# frozen_string_literal: true

module Adapters
  module Pest
    module Mappers
      # ActiveRecord → delete-usage wire（業務判断なし。関連件数のみ）。
      module PestDeleteUsageWireMapper
        Wire = Data.define(:pesticides_count)

        module_function

        # @param pest [Pest]
        # @return [Wire]
        def from_model(pest)
          Wire.new(pesticides_count: pest.pesticides.count)
        end
      end
    end
  end
end
