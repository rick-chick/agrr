# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Calculators
      class AgrrFieldsConfigCalculator
        # @param plan_fields [Array<Hash>] :id, :name, :area, :daily_fixed_cost
        # @return [Array<Hash>]
        def self.build(plan_fields:)
          Array(plan_fields).map do |field|
            {
              field_id: field.fetch(:id).to_s,
              name: field.fetch(:name),
              area: field.fetch(:area),
              daily_fixed_cost: field[:daily_fixed_cost] || 0.0
            }
          end
        end
      end
    end
  end
end
