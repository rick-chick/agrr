# frozen_string_literal: true

module Domain
  module Pesticide
    module Ports
      class PesticideListInputPort
        def call
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end
