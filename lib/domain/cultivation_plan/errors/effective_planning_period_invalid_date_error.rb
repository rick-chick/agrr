# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Errors
      class EffectivePlanningPeriodInvalidDateError < StandardError
        attr_reader :raw_value, :allocation_id, :field, :move

        def initialize(raw_value:, field:, allocation_id: nil, move: nil)
          @raw_value = raw_value
          @allocation_id = allocation_id
          @field = field
          @move = move
          super("Invalid #{field} date: #{raw_value.inspect}")
        end
      end
    end
  end
end
