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

        def list_index_for_user(user)
          raise NotImplementedError, "Subclasses must implement list_index_for_user"
        end

        def find_authorized_for_view(user, id)
          raise NotImplementedError, "Subclasses must implement find_authorized_for_view"
        end

        def find_authorized_for_edit(user, id)
          raise NotImplementedError, "Subclasses must implement find_authorized_for_edit"
        end

        def find_authorized_model_for_view(user, id)
          raise NotImplementedError, "Subclasses must implement find_authorized_model_for_view"
        end

        def find_authorized_model_for_edit(user, id)
          raise NotImplementedError, "Subclasses must implement find_authorized_model_for_edit"
        end

        def find_authorized_fertilize_loaded_bundle!(user, id, for_edit:)
          raise NotImplementedError, "Subclasses must implement find_authorized_fertilize_loaded_bundle!"
        end

        def find_model(id)
          raise NotImplementedError, "Subclasses must implement find_model"
        end

        def create_for_user(user, attrs)
          raise NotImplementedError, "Subclasses must implement create_for_user"
        end

        def update_for_user(user, id, attrs)
          raise NotImplementedError, "Subclasses must implement update_for_user"
        end

        def soft_destroy_with_undo(user:, fertilize_id:, auto_hide_after:, translator:)
          raise NotImplementedError, "Subclasses must implement soft_destroy_with_undo"
        end

        # AI API: ユーザー肥料を agrr 応答の商品名で検索（なければ nil）。戻りは永続 Fertilize。
        def find_user_owned_non_reference_fertilize_record_by_name(user_id:, name:)
          raise NotImplementedError, "Subclasses must implement find_user_owned_non_reference_fertilize_record_by_name"
        end
      end
    end
  end
end
