# frozen_string_literal: true

module Domain
  module Field
    module Ports
      class FieldDetailOutputPort
        def on_success(field_with_farm)
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        def on_failure(error_dto)
          raise NotImplementedError, "Subclasses must implement on_failure"
        end
      end
    end
  end
end
