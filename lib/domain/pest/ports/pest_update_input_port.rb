# frozen_string_literal: true

module Domain
  module Pest
    module Ports
      class PestUpdateInputPort
        def call(input_dto)
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end
