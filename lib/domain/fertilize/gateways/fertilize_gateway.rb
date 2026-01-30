# frozen_string_literal: true

module Domain
  module Fertilize
    module Gateways
      class FertilizeGateway
        def list
          raise NotImplementedError, "Subclasses must implement list"
        end

        def find_by_id(fertilize_id)
          raise NotImplementedError, "Subclasses must implement find_by_id"
        end

        def create(create_input_dto)
          raise NotImplementedError, "Subclasses must implement create"
        end

        def update(fertilize_id, update_input_dto)
          raise NotImplementedError, "Subclasses must implement update"
        end
      end
    end
  end
end

