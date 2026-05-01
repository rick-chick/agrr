# frozen_string_literal: true

module Domain
  module Pest
    module Ports
      class PestUpdateOutputPort
        def on_success(pest_entity)
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        # @param failure_dto [Domain::Pest::Dtos::PestUpdateFailureDto]
        def on_failure(failure_dto)
          raise NotImplementedError, "Subclasses must implement on_failure"
        end
      end
    end
  end
end
