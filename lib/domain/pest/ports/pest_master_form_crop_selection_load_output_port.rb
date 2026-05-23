# frozen_string_literal: true

module Domain
  module Pest
    module Ports
      class PestHtmlCropSelectionLoadOutputPort
        # @param bundle [Domain::Pest::Dtos::PestHtmlCropSelectionLoadBundle]
        def on_success(bundle)
          raise NotImplementedError, "Subclasses must implement on_success"
        end
      end
    end
  end
end
