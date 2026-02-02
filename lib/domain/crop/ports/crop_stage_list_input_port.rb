# frozen_string_literal: true

module Domain
  module Crop
    module Ports
      class CropStageListInputPort
        def call(input_dto)
          raise NotImplementedError
        end
      end
    end
  end
end