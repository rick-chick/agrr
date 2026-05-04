# frozen_string_literal: true

module Domain
  module Crop
    module Ports
      module CropNestedJsonNotFoundFailurePort
        def on_not_found
          raise NotImplementedError, "#{self.class} must implement #on_not_found"
        end
      end
    end
  end
end
