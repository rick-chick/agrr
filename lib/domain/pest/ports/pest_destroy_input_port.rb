# frozen_string_literal: true

module Domain
  module Pest
    module Ports
      class PestDestroyInputPort
        def call(pest_id)
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end
