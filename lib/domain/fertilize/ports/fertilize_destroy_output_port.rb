# frozen_string_literal: true

module Domain
  module Fertilize
    module Ports
      class FertilizeDestroyOutputPort
        def on_success(destroy_output_dto)
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        def on_failure(error_dto)
          raise NotImplementedError, "Subclasses must implement on_failure"
        end
      end
    end
  end
end
