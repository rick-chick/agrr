# frozen_string_literal: true

module Domain
  module Crop
    module Ports
      class CropListOutputPort
        def on_success(crops)
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        def on_failure(error_dto)
          raise NotImplementedError, "Subclasses must implement on_failure"
        end
      end
    end
  end
end
