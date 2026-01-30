# frozen_string_literal: true

module Domain
  module Pesticide
    module Gateways
      class PesticideGateway
        def list
          raise NotImplementedError, "Subclasses must implement list"
        end

        def find_by_id(pesticide_id)
          raise NotImplementedError, "Subclasses must implement find_by_id"
        end

        def create(create_input_dto)
          raise NotImplementedError, "Subclasses must implement create"
        end

        def update(pesticide_id, update_input_dto)
          raise NotImplementedError, "Subclasses must implement update"
        end

        def destroy(pesticide_id)
          raise NotImplementedError, "Subclasses must implement destroy"
        end
      end
    end
  end
end
