# frozen_string_literal: true

module Domain
  module Field
    module Ports
      class FieldListOutputPort
        def on_success(fields)
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        def on_failure(error_dto)
          raise NotImplementedError, "Subclasses must implement on_failure"
        end
      end
    end
  end
end
