# frozen_string_literal: true

module Domain
  module Field
    module Gateways
      class FieldGateway
        def list_by_farm(farm_id, user_id)
          raise NotImplementedError, "Subclasses must implement list_by_farm"
        end

        def find_by_id_and_user(field_id, user_id)
          raise NotImplementedError, "Subclasses must implement find_by_id_and_user"
        end

        def create(create_input_dto, farm_id, user_id)
          raise NotImplementedError, "Subclasses must implement create"
        end

        def update(field_id, update_input_dto, user_id)
          raise NotImplementedError, "Subclasses must implement update"
        end

        def destroy(field_id, user_id)
          raise NotImplementedError, "Subclasses must implement destroy"
        end

        def find_authorized_for_view(user, id)
          raise NotImplementedError, "Subclasses must implement find_authorized_for_view"
        end

        def find_authorized_for_edit(user, id)
          raise NotImplementedError, "Subclasses must implement find_authorized_for_edit"
        end

        def create_for_user(user, farm_id, attrs)
          raise NotImplementedError, "Subclasses must implement create_for_user"
        end

        def update_for_user(user, id, attrs)
          raise NotImplementedError, "Subclasses must implement update_for_user"
        end

        def soft_destroy_with_undo(user:, field_id:, auto_hide_after: 5000, translator: nil)
          raise NotImplementedError, "Subclasses must implement soft_destroy_with_undo"
        end
      end
    end
  end
end
