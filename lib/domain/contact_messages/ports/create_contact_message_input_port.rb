# frozen_string_literal: true

module Domain
  module ContactMessages
    module Ports
      class CreateContactMessageInputPort
        def call(input_dto)
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end
