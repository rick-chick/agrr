# frozen_string_literal: true

module Domain
  module Pest
    module Dtos
      class PestDestroyOutputDto
        attr_reader :undo

        def initialize(undo:)
          @undo = undo
        end
      end
    end
  end
end
