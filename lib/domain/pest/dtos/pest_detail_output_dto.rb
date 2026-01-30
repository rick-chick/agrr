# frozen_string_literal: true

module Domain
  module Pest
    module Dtos
      class PestDetailOutputDto
        attr_reader :pest, :pest_model

        def initialize(pest:, pest_model: nil)
          @pest = pest
          @pest_model = pest_model
        end
      end
    end
  end
end
