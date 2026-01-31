# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class SunshineRequirementOutputDto
        attr_reader :requirement

        def initialize(requirement:)
          @requirement = requirement
        end
      end
    end
  end
end