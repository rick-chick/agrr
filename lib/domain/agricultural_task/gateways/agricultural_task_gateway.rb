# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Gateways
      class AgriculturalTaskGateway
        def list
          raise NotImplementedError, "Subclasses must implement list"
        end

        def find_by_id(task_id)
          raise NotImplementedError, "Subclasses must implement find_by_id"
        end

        def create(create_input_dto)
          raise NotImplementedError, "Subclasses must implement create"
        end

        def update(task_id, update_input_dto)
          raise NotImplementedError, "Subclasses must implement update"
        end

        def destroy(task_id)
          raise NotImplementedError, "Subclasses must implement destroy"
        end

        def list_for_index(user:, is_admin:, filter: nil, query: nil)
          raise NotImplementedError, "Subclasses must implement list_for_index"
        end

        # 一覧 HTML 用: 管理者のみ参照農作業エンティティ一覧（非管理者は []）
        def reference_tasks_for_index(is_admin:)
          raise NotImplementedError, "Subclasses must implement reference_tasks_for_index"
        end

        def find_authorized_for_view(user, id)
          raise NotImplementedError, "Subclasses must implement find_authorized_for_view"
        end

        def authorized_agricultural_task_detail_output(user, id)
          raise NotImplementedError, "Subclasses must implement authorized_agricultural_task_detail_output"
        end

        def find_authorized_for_edit(user, id)
          raise NotImplementedError, "Subclasses must implement find_authorized_for_edit"
        end

        # 表層（コントローラ等）で AR インスタンスが必要な場合のみ
        def find_authorized_model_for_view(user, id)
          raise NotImplementedError, "Subclasses must implement find_authorized_model_for_view"
        end

        def find_authorized_model_for_edit(user, id)
          raise NotImplementedError, "Subclasses must implement find_authorized_model_for_edit"
        end

        def find_authorized_agricultural_task_loaded_bundle!(user, id, for_edit:)
          raise NotImplementedError, "Subclasses must implement find_authorized_agricultural_task_loaded_bundle!"
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

        def recent_for_user(user, limit: nil)
          raise NotImplementedError, "Subclasses must implement recent_for_user"
        end

        def any_visible_for_user?(user)
          raise NotImplementedError, "Subclasses must implement any_visible_for_user?"
        end

        def soft_destroy_with_undo(user:, task_id:, auto_hide_after:, translator:)
          raise NotImplementedError, "Subclasses must implement soft_destroy_with_undo"
        end
      end
    end
  end
end
