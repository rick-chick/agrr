# frozen_string_literal: true

module Domain
  module Pesticide
    module Ports
      class PesticideDestroyInputPort
        def call(pesticide_id)
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end
