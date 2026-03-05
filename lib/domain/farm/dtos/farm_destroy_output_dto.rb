# frozen_string_literal: true

module Domain
  module Farm
    module Dtos
      class FarmDestroyOutputDto
        attr_reader :undo, :farm_name

        def initialize(undo:, farm_name:)
          @undo = undo
          @farm_name = farm_name
        end
      end
    end
  end
end