# frozen_string_literal: true

module Domain
  module Field
    module Dtos
      class FieldDetailOutputDto
        attr_reader :field

        def initialize(field:)
          @field = field
        end
      end
    end
  end
end
