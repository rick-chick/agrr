# frozen_string_literal: true

module Domain
  module Farm
    module Ports
      class FarmUpdateOutputPort
        def on_success(farm_entity)
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        def on_failure(error_dto)
          raise NotImplementedError, "Subclasses must implement on_failure"
        end
      end
    end
  end
end