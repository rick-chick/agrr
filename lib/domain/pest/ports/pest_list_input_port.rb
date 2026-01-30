# frozen_string_literal: true

module Domain
  module Pest
    module Ports
      class PestListInputPort
        def call
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end
