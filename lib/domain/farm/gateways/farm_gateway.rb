# frozen_string_literal: true

module Domain
  module Farm
    module Gateways
      class FarmGateway
        def find_by_id(id)
          raise NotImplementedError, "Subclasses must implement find_by_id"
        end

        def find_by_user_id(user_id)
          raise NotImplementedError, "Subclasses must implement find_by_user_id"
        end

        def create(farm_data)
          raise NotImplementedError, "Subclasses must implement create"
        end

        def update(id, farm_data)
          raise NotImplementedError, "Subclasses must implement update"
        end

        def delete(id)
          raise NotImplementedError, "Subclasses must implement delete"
        end

        def exists?(id)
          raise NotImplementedError, "Subclasses must implement exists?"
        end
      end
    end
  end
end
