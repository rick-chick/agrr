# frozen_string_literal: true

module Domain
  module Fertilize
    module Ports
      class FertilizeDestroyInputPort
        def call(fertilize_id)
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end
