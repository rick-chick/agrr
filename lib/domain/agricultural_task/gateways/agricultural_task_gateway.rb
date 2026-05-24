# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Gateways
      class AgriculturalTaskGateway
        def list_user_owned_tasks(user_id:, query: nil)
          raise NotImplementedError, "Subclasses must implement list_user_owned_tasks"
        end

        def list_reference_tasks(query: nil)
          raise NotImplementedError, "Subclasses must implement list_reference_tasks"
        end

        def list_user_and_reference_tasks(user_id:, query: nil)
          raise NotImplementedError, "Subclasses must implement list_user_and_reference_tasks"
        end

        # 詳細 DTO。認可は Interactor 側（R0）。
        def find_agricultural_task_show_detail(id)
          raise NotImplementedError, "Subclasses must implement find_agricultural_task_show_detail"
        end

        def find_by_id(id)
          raise NotImplementedError, "Subclasses must implement find_by_id"
        end

        def create_for_user(user, attrs)
          raise NotImplementedError, "Subclasses must implement create_for_user"
        end

        # @param selected_crop_ids [Array<Integer>, nil] nil のとき作物テンプレート同期を行わない（API 等）
        def update_for_user(user, id, attrs, selected_crop_ids: nil)
          raise NotImplementedError, "Subclasses must implement update_for_user"
        end

        def soft_delete_with_undo(user:, task_id:, auto_hide_after:, translator:)
          raise NotImplementedError, "Subclasses must implement soft_delete_with_undo"
        end
      end
    end
  end
end
