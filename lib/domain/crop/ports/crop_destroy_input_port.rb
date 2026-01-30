# frozen_string_literal: true

module Domain
  module Crop
    module Ports
      class CropDestroyInputPort
        def call(crop_id)
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end
