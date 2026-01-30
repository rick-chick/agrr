# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Ports
      class AgriculturalTaskCreateInputPort
        def call(create_input_dto)
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end
