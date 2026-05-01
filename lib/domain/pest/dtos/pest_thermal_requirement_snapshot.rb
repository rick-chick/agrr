# frozen_string_literal: true

module Domain
  module Pest
    module Dtos
      class PestThermalRequirementSnapshot
        attr_reader :required_gdd, :first_generation_gdd

        def initialize(required_gdd:, first_generation_gdd:)
          @required_gdd = required_gdd
          @first_generation_gdd = first_generation_gdd
        end
      end
    end
  end
end
