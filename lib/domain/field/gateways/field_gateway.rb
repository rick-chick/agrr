# frozen_string_literal: true

module Domain
  module Field
    module Gateways
      class FieldGateway
        def authorized_farm_fields_list(farm_id, user_id)
          raise NotImplementedError, "Subclasses must implement authorized_farm_fields_list"
        end

        def field_with_farm_for_user(field_id, user_id)
          raise NotImplementedError, "Subclasses must implement field_with_farm_for_user"
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

        def find_authorized_field_loaded_in_farm!(user, farm_id, field_id)
          raise NotImplementedError, "Subclasses must implement find_authorized_field_loaded_in_farm!"
        end

        def create_for_user(user, farm_id, attrs)
          raise NotImplementedError, "Subclasses must implement create_for_user"
        end

        def update_for_user(user, id, attrs)
          raise NotImplementedError, "Subclasses must implement update_for_user"
        end

        def soft_destroy_with_undo(user:, field_id:, auto_hide_after:, translator:)
          raise NotImplementedError, "Subclasses must implement soft_destroy_with_undo"
        end

        # マスタCRUD 新規: 認可済み農場 AR に紐づく未保存圃場（コントローラで association.build しない）
        def build_blank_field_for_master_form!(persisted_farm:)
          raise NotImplementedError, "Subclasses must implement build_blank_field_for_master_form!"
        end
      end
    end
  end
end
