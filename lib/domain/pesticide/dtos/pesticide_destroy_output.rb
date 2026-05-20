# frozen_string_literal: true

module Domain
  module Pesticide
    module Dtos
      class PesticideDestroyOutput
        attr_reader :undo

        def initialize(undo:)
          @undo = undo
        end
      end
    end
  end
end
