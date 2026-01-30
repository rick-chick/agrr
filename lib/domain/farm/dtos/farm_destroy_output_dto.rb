# frozen_string_literal: true

module Domain
  module Farm
    module Dtos
      class FarmDestroyOutputDto
        attr_reader :undo

        def initialize(undo:)
          @undo = undo
        end
      end
    end
  end
end