# frozen_string_literal: true

module Domain
  module Crop
    module Ports
      class CropMastersTaskTemplateUpdateOutputPort
        def on_success(row)
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        def on_failure(failure_dto)
          raise NotImplementedError, "Subclasses must implement on_failure"
        end
      end
    end
  end
end
