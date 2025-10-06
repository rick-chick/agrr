# frozen_string_literal: true

module Domain
  module Crop
    module Gateways
      class CropGateway
        def find_by_id(id)
          raise NotImplementedError, "Subclasses must implement find_by_id"
        end

        def find_all_visible_for(user_id)
          raise NotImplementedError, "Subclasses must implement find_all_visible_for"
        end

        def create(crop_data)
          raise NotImplementedError, "Subclasses must implement create"
        end

        def update(id, crop_data)
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


