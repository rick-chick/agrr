# frozen_string_literal: true

module Domain
  module Pesticide
    module Ports
      class PesticideDetailInputPort
        def call(pesticide_id)
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end
