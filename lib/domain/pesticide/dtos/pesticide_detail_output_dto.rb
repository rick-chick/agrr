# frozen_string_literal: true

module Domain
  module Pesticide
    module Dtos
      class PesticideDetailOutputDto
        attr_reader :pesticide

        def initialize(pesticide:)
          @pesticide = pesticide
        end
      end
    end
  end
end
