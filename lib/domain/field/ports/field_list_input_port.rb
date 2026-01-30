# frozen_string_literal: true

module Domain
  module Field
    module Ports
      class FieldListInputPort
        def call(farm_id)
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end
