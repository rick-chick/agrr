# frozen_string_literal: true

module Domain
  module Fertilize
    module Ports
      class FertilizeUpdateOutputPort
        def on_success(fertilize_entity)
          raise NotImplementedError, "Subclasses must implement on_success"
        end

        # @param failure_dto [Domain::Fertilize::Dtos::FertilizeUpdateFailure]
        def on_failure(failure_dto)
          raise NotImplementedError, "Subclasses must implement on_failure"
        end
      end
    end
  end
end
