# frozen_string_literal: true

module Domain
  module Crop
    module Ports
      class CropTaskScheduleBlueprintDestroyOutputPort
        def on_forbidden
          raise NotImplementedError, "Subclasses must implement on_forbidden"
        end

        def on_not_found(blueprint_id:)
          raise NotImplementedError, "Subclasses must implement on_not_found"
        end

        def on_reload_failed(blueprint_id:)
          raise NotImplementedError, "Subclasses must implement on_reload_failed"
        end

        def on_success(output)
          raise NotImplementedError, "Subclasses must implement on_success"
        end
      end
    end
  end
end
