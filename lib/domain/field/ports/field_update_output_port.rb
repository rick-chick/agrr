# frozen_string_literal: true

module Domain
  module Field
    module Ports
      class FieldUpdateOutputPort
        def on_success(field)
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        def on_failure(error_dto)
          raise NotImplementedError, "Subclasses must implement on_failure"
        end
      end
    end
  end
end
