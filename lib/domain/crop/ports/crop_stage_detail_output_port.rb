# frozen_string_literal: true

module Domain
  module Crop
    module Ports
      class CropStageDetailOutputPort
        def on_success(success_dto)
          raise NotImplementedError
        end

        def on_failure(failure_dto)
          raise NotImplementedError
        end
      end
    end
  end
end