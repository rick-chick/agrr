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

        # @return [Domain::AgriculturalTask::Entities::AgriculturalTaskEntity, nil]
        def find_by_reference_and_name(name:)
          raise NotImplementedError, "Subclasses must implement find_by_reference_and_name"
        end

        # @return [Domain::AgriculturalTask::Entities::AgriculturalTaskEntity, nil]
        def find_by_user_id_and_name(user_id:, name:)
          raise NotImplementedError, "Subclasses must implement find_by_user_id_and_name"
        end

        def create(attrs)
          raise NotImplementedError, "Subclasses must implement create"
        end

        def update(id, attrs)
          raise NotImplementedError, "Subclasses must implement update"
        end

        def within_transaction(&block)
          raise NotImplementedError, "Subclasses must implement within_transaction"
        end

        def soft_delete_with_undo(user:, task_id:, auto_hide_after:, toast_message:)
          raise NotImplementedError, "Subclasses must implement soft_delete_with_undo"
        end
      end
    end
  end
end
