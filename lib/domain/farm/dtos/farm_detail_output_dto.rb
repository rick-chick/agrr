# frozen_string_literal: true

module Domain
  module Farm
    module Dtos
      class FarmDetailOutputDto
        attr_reader :farm, :fields

        def initialize(farm:, fields:)
          @farm = farm
          @fields = fields
        end
      end
    end
  end
end
