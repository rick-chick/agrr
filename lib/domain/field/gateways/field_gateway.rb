# frozen_string_literal: true

module Domain
  module Field
    module Gateways
      class FieldGateway
        def farm_fields_list(farm_id)
          raise NotImplementedError, "Subclasses must implement farm_fields_list"
        end

        def field_with_farm(field_id)
          raise NotImplementedError, "Subclasses must implement field_with_farm"
        end

        def create(create_input_dto, farm_id, farm_access_filter:)
          raise NotImplementedError, "Subclasses must implement create"
        end

        def update(field_id, update_input_dto, farm_access_filter:)
          raise NotImplementedError, "Subclasses must implement update"
        end

        def delete(field_id)
          raise NotImplementedError, "Subclasses must implement destroy"
        end

        def find_field_loaded_in_farm!(farm_id, field_id)
          raise NotImplementedError, "Subclasses must implement find_field_loaded_in_farm!"
        end

      end
    end
  end
end
