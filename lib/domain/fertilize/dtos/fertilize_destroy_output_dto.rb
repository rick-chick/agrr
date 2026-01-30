# frozen_string_literal: true

module Domain
  module Fertilize
    module Dtos
      class FertilizeDestroyOutputDto
        attr_reader :undo

        def initialize(undo:)
          @undo = undo
        end
      end
    end
  end
end
