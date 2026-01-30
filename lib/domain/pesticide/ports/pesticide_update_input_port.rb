# frozen_string_literal: true

module Domain
  module Pesticide
    module Ports
      class PesticideUpdateInputPort
        def call(input_dto)
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end
