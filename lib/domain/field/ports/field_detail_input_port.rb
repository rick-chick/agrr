# frozen_string_literal: true

module Domain
  module Field
    module Ports
      class FieldDetailInputPort
        def call(field_id)
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end
