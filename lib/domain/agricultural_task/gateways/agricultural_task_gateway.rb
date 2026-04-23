# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Gateways
      class AgriculturalTaskGateway
        class << self
          def default
            @default ||= Adapters::AgriculturalTask::Gateways::AgriculturalTaskActiveRecordGateway.new
          end

          attr_writer :default

          def default_reset!
            @default = nil
          end
        end

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

        def visible_records(user)
          raise NotImplementedError, "Subclasses must implement visible_records"
        end

        def user_owned_non_reference_records(user)
          raise NotImplementedError, "Subclasses must implement user_owned_non_reference_records"
        end

        def reference_records(region: nil)
          raise NotImplementedError, "Subclasses must implement reference_records"
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

        def list_from_relation(relation)
          raise NotImplementedError, "Subclasses must implement list_from_relation"
        end

        # 管理者一覧など、全件を起点にした ActiveRecord::Relation（Adapter でモデル全件相当）
        def all_records_relation
          raise NotImplementedError, "Subclasses must implement all_records_relation"
        end

        def soft_destroy_with_undo(user:, task_id:, auto_hide_after:, translator:)
          raise NotImplementedError, "Subclasses must implement soft_destroy_with_undo"
        end
      end
    end
  end
end
