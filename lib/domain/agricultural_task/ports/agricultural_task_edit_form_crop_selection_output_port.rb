# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Ports
      class AgriculturalTaskEditFormCropSelectionOutputPort
        def on_success(success_dto)
          raise NotImplementedError, "Subclasses must implement on_success"
        end
      end
    end
  end
end
