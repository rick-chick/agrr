# frozen_string_literal: true

module Domain
  module Farm
    module Gateways
      class FarmGateway
        def list
          raise NotImplementedError, "Subclasses must implement list"
        end

        def find_by_id(farm_id)
          raise NotImplementedError, "Subclasses must implement find_by_id"
        end

        def create(create_input_dto)
          raise NotImplementedError, "Subclasses must implement create"
        end

        def update(farm_id, update_input_dto)
          raise NotImplementedError, "Subclasses must implement update"
        end

        def destroy(farm_id)
          raise NotImplementedError, "Subclasses must implement destroy"
        end
      end
    end
  end
end