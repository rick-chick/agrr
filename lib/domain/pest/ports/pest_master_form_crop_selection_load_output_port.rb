# frozen_string_literal: true

module Domain
  module Pest
    module Ports
      class PestMasterFormCropSelectionLoadOutputPort
        # @param bundle [Domain::Pest::Dtos::PestMasterFormCropSelectionBundle]
        def on_success(bundle)
          raise NotImplementedError, "Subclasses must implement on_success"
        end
      end
    end
  end
end
