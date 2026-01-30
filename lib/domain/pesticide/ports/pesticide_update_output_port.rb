# frozen_string_literal: true

module Domain
  module Pesticide
    module Ports
      class PesticideUpdateOutputPort
        def on_success(pesticide_entity)
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        def on_failure(error_dto)
          raise NotImplementedError, "Subclasses must implement on_failure"
        end
      end
    end
  end
end
