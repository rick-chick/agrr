# frozen_string_literal: true

module Adapters
  module AgriculturalTask
    module Gateways
      class AgriculturalTaskActiveRecordGateway < Domain::AgriculturalTask::Gateways::AgriculturalTaskGateway
        include Adapters::Shared::Concerns::ActiveRecordTransactional

        def initialize(deletion_undo_gateway:, sql_like_sanitize_port:)
          @deletion_undo_gateway = deletion_undo_gateway
          @sql_like_sanitize_port = sql_like_sanitize_port
        end

        def list_user_owned_tasks(user_id:, query: nil)
          scope = ::AgriculturalTask.where(user_id: user_id, is_reference: false)
          scope = apply_search_scope(scope, query) if Domain::Shared::ValidationHelpers.present?(query)
          scope.recent.map { |record| Adapters::AgriculturalTask::Mappers::AgriculturalTaskMapper.agricultural_task_entity_from_record(record) }
        end

        def list_reference_tasks(query: nil)
          scope = ::AgriculturalTask.where(is_reference: true)
          scope = apply_search_scope(scope, query) if Domain::Shared::ValidationHelpers.present?(query)
          scope.recent.map { |record| Adapters::AgriculturalTask::Mappers::AgriculturalTaskMapper.agricultural_task_entity_from_record(record) }
        end

        def list_user_and_reference_tasks(user_id:, query: nil)
          scope = ::AgriculturalTask.where("is_reference = ? OR user_id = ?", true, user_id)
          scope = apply_search_scope(scope, query) if Domain::Shared::ValidationHelpers.present?(query)
          scope.recent.map { |record| Adapters::AgriculturalTask::Mappers::AgriculturalTaskMapper.agricultural_task_entity_from_record(record) }
        end

        def find_agricultural_task_show_detail(id)
          task = ::AgriculturalTask.includes(:crops).find(id)
          Adapters::AgriculturalTask::Mappers::AgriculturalTaskMapper.detail_output_dto_from_record(task)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def find_by_id(id)
          Adapters::AgriculturalTask::Mappers::AgriculturalTaskMapper.agricultural_task_entity_from_record(find_agricultural_task_model!(id))
        end

        def find_by_reference_and_name(name:)
          record = ::AgriculturalTask.reference.find_by(name: name)
          return nil unless record

          Adapters::AgriculturalTask::Mappers::AgriculturalTaskMapper.agricultural_task_entity_from_record(record)
        end

        def find_by_user_id_and_name(user_id:, name:)
          record = ::AgriculturalTask.user_owned.where(user_id: user_id).find_by(name: name)
          return nil unless record

          Adapters::AgriculturalTask::Mappers::AgriculturalTaskMapper.agricultural_task_entity_from_record(record)
        end

        def create(attrs)
          task = ::AgriculturalTask.new(attrs.to_h.symbolize_keys)
          raise Domain::Shared::Exceptions::RecordInvalid, task.errors.full_messages.join(", ") unless task.save

          Adapters::AgriculturalTask::Mappers::AgriculturalTaskMapper.agricultural_task_entity_from_record(task)
        end

        def update(id, attrs)
          task = find_agricultural_task_model!(id)
          raise Domain::Shared::Exceptions::RecordInvalid, task.errors.full_messages.join(", ") unless task.update(attrs.to_h.symbolize_keys)

          Adapters::AgriculturalTask::Mappers::AgriculturalTaskMapper.agricultural_task_entity_from_record(task.reload)
        end

        def soft_delete_with_undo(user:, task_id:, auto_hide_after: 5000, toast_message:)
          task = find_agricultural_task_model!(task_id)
          undo_gw = @deletion_undo_gateway
          event = undo_gw.schedule(
            resource_type: task.class.name,
            resource_id: task.id,
            actor_id: user.id,
            toast_message: toast_message,
            auto_hide_after: auto_hide_after
          )
          { success: true, undo_entity: event }
        rescue Domain::Shared::Exceptions::RecordNotFound
          raise
        rescue StandardError => e
          { success: false, error_dto: Domain::Shared::Dtos::Error.new(e.message) }
        end

        private

        def apply_search_scope(scope, term)
          return scope if Domain::Shared::ValidationHelpers.blank?(term)

          sanitized = @sql_like_sanitize_port.sanitize_like(term)
          q = "%#{sanitized}%"
          scope.where(
            "agricultural_tasks.name LIKE :query OR COALESCE(agricultural_tasks.description, '') LIKE :query",
            query: q
          )
        end

        def find_agricultural_task_model!(id)
          ::AgriculturalTask.find(id)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

      end
    end
  end
end
