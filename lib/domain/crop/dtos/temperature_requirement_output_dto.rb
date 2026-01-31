# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class TemperatureRequirementOutputDto
        attr_reader :requirement

        def initialize(requirement:)
          @requirement = requirement
        end
      end
    end
  end
end