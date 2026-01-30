# frozen_string_literal: true

module Domain
  module Field
    module Ports
      class FieldCreateInputPort
        def call(create_input_dto, farm_id)
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end
