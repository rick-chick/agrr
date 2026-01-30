# frozen_string_literal: true

module Domain
  module Farm
    module Ports
      class FarmCreateInputPort
        def call(input_dto)
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end