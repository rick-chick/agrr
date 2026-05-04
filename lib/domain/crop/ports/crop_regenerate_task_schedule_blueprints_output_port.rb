# frozen_string_literal: true

module Domain
  module Crop
    module Ports
      class CropRegenerateTaskScheduleBlueprintsOutputPort
        def on_success
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        def on_failure(error)
          raise NotImplementedError, "Subclasses must implement on_failure"
        end
      end
    end
  end
end
