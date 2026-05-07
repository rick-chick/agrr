# frozen_string_literal: true

module Domain
  module Crop
    module Ports
      class CropTaskScheduleBlueprintUpdatePositionOutputPort
        def on_forbidden
          raise NotImplementedError, "Subclasses must implement on_forbidden"
        end

        def on_bad_request(message)
          raise NotImplementedError, "Subclasses must implement on_bad_request"
        end

        def on_success(payload)
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        def on_not_found(error_message)
          raise NotImplementedError, "Subclasses must implement on_not_found"
        end

        def on_mutation_failure(status, error_message)
          raise NotImplementedError, "Subclasses must implement on_mutation_failure"
        end
      end
    end
  end
end
