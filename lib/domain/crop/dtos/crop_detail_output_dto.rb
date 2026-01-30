# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropDetailOutputDto
        attr_reader :crop

        def initialize(crop:)
          @crop = crop
        end

      end
    end
  end
end
