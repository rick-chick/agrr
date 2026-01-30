# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropDestroyOutputDto
        attr_reader :undo

        def initialize(undo:)
          @undo = undo
        end
      end
    end
  end
end
