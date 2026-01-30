# frozen_string_literal: true

module Domain
  module Fertilize
    module Ports
      class FertilizeListInputPort
        def call
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end
