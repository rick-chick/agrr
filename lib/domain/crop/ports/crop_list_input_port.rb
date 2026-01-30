# frozen_string_literal: true

module Domain
  module Crop
    module Ports
      class CropListInputPort
        def call
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end
