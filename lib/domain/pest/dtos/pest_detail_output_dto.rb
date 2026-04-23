# frozen_string_literal: true

module Domain
  module Pest
    module Dtos
      class PestDetailOutputDto
        attr_reader :pest

        def initialize(pest:)
          @pest = pest
        end
      end
    end
  end
end
