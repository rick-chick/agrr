# frozen_string_literal: true

module Domain
  module Fertilize
    module Gateways
      class FertilizeGateway
        def find_by_id(id)
          raise NotImplementedError, "Subclasses must implement find_by_id"
        end
        
        def find_all_reference
          raise NotImplementedError, "Subclasses must implement find_all_reference"
        end
        
        def create(fertilize_data)
          raise NotImplementedError, "Subclasses must implement create"
        end
        
        def update(id, fertilize_data)
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

