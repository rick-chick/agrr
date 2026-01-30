# frozen_string_literal: true

module Domain
  module Fertilize
    module Ports
      class FertilizeCreateInputPort
        def call(input_dto)
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end
