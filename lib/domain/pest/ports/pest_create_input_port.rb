# frozen_string_literal: true

module Domain
  module Pest
    module Ports
      class PestCreateInputPort
        def call(input_dto)
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end
