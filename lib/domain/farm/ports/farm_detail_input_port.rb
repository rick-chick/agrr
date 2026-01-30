# frozen_string_literal: true

module Domain
  module Farm
    module Ports
      class FarmDetailInputPort
        def call(farm_id)
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end