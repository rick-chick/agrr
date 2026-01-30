# frozen_string_literal: true

module Domain
  module Farm
    module Ports
      class FarmListInputPort
        def call
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end