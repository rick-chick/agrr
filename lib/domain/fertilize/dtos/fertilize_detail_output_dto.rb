# frozen_string_literal: true

module Domain
  module Fertilize
    module Dtos
      class FertilizeDetailOutputDto
        attr_reader :fertilize

        def initialize(fertilize:)
          @fertilize = fertilize
        end
      end
    end
  end
end
