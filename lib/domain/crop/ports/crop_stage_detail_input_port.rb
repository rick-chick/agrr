# frozen_string_literal: true

module Domain
  module Crop
    module Ports
      class CropStageDetailInputPort
        def call(input_dto)
          raise NotImplementedError
        end
      end
    end
  end
end