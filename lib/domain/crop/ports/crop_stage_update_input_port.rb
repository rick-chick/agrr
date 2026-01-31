# frozen_string_literal: true

module Domain
  module Crop
    module Ports
      class CropStageUpdateInputPort
        def call(input_dto)
          raise NotImplementedError, "Subclasses must implement call"
        end
      end
    end
  end
end