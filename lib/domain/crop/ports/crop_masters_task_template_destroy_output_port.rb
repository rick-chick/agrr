# frozen_string_literal: true

module Domain
  module Crop
    module Ports
      class CropMastersTaskTemplateDestroyOutputPort
        def on_success
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        def on_failure(failure_dto)
          raise NotImplementedError, "Subclasses must implement on_failure"
        end
      end
    end
  end
end
