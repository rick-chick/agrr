# frozen_string_literal: true

module Adapters
  module AgriculturalTask
    module Gateways
      class AgriculturalTaskActiveRecordGateway < Domain::AgriculturalTask::Gateways::AgriculturalTaskGateway
        attr_accessor :translator
        def list
          ::AgriculturalTask.all.map { |record| Adapters::AgriculturalTask::Mappers::AgriculturalTaskMapper.agricultural_task_entity_from_record(record) }
        end

        def list_from_relation(relation)
          relation.map { |record| Adapters::AgriculturalTask::Mappers::AgriculturalTaskMapper.agricultural_task_entity_from_record(record) }
        end

        def find_by_id(task_id)
          task = ::AgriculturalTask.find(task_id)
          Adapters::AgriculturalTask::Mappers::AgriculturalTaskMapper.agricultural_task_entity_from_record(task)
        rescue ActiveRecord::RecordNotFound
          raise StandardError, "AgriculturalTask not found"
        end

        def create(create_input_dto)
          task = ::AgriculturalTask.new(
            name: create_input_dto.name,
            description: create_input_dto.description,
            time_per_sqm: create_input_dto.time_per_sqm,
            weather_dependency: create_input_dto.weather_dependency,
            required_tools: create_input_dto.required_tools,
            skill_level: create_input_dto.skill_level,
            region: create_input_dto.region,
            task_type: create_input_dto.task_type
          )
          raise StandardError, task.errors.full_messages.join(", ") unless task.save

          Adapters::AgriculturalTask::Mappers::AgriculturalTaskMapper.agricultural_task_entity_from_record(task)
        end

        def update(task_id, update_input_dto)
          task = ::AgriculturalTask.find(task_id)
          attrs = {}
          attrs[:name] = update_input_dto.name if update_input_dto.name.present?
          attrs[:description] = update_input_dto.description if !update_input_dto.description.nil?
          attrs[:time_per_sqm] = update_input_dto.time_per_sqm if !update_input_dto.time_per_sqm.nil?
          attrs[:weather_dependency] = update_input_dto.weather_dependency if !update_input_dto.weather_dependency.nil?
          attrs[:required_tools] = update_input_dto.required_tools if !update_input_dto.required_tools.nil?
          attrs[:skill_level] = update_input_dto.skill_level if !update_input_dto.skill_level.nil?
          attrs[:region] = update_input_dto.region if !update_input_dto.region.nil?
          attrs[:task_type] = update_input_dto.task_type if !update_input_dto.task_type.nil?

          task.update(attrs)
          raise StandardError, task.errors.full_messages.join(", ") if task.errors.any?

          Adapters::AgriculturalTask::Mappers::AgriculturalTaskMapper.agricultural_task_entity_from_record(task.reload)
        rescue ActiveRecord::RecordNotFound
          raise StandardError, "AgriculturalTask not found"
        end

        def destroy(task_id)
          task = ::AgriculturalTask.find(task_id)
          DeletionUndo::Manager.schedule(
            record: task,
            actor: ::User.find(task.user_id),
            toast_message: @translator.t("agricultural_tasks.undo.toast", name: task.name)
          )
        rescue ActiveRecord::RecordNotFound
          raise StandardError, "AgriculturalTask not found"
        rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError
          raise StandardError, @translator.t("agricultural_tasks.flash.cannot_delete_in_use")
        rescue DeletionUndo::Error => e
          raise StandardError, e.message
        end

        def visible_records(user)
          if user.admin?
            ::AgriculturalTask.where("is_reference = ? OR user_id = ?", true, user.id)
          else
            ::AgriculturalTask.where(user_id: user.id, is_reference: false)
          end
        end

        def user_owned_non_reference_records(user)
          ::AgriculturalTask.where(user_id: user.id, is_reference: false)
        end

        def reference_records(region: nil)
          scope = ::AgriculturalTask.reference
          region ? scope.where(region: region) : scope
        end

        def find_authorized_model_for_view(user, id)
          task = find_agricultural_task_model!(id)
          unless Domain::Shared::Policies::AgriculturalTaskPolicy.view_allowed?(user, is_reference: task.is_reference, user_id: task.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          task
        end

        def find_authorized_model_for_edit(user, id)
          task = find_agricultural_task_model!(id)
          unless Domain::Shared::Policies::AgriculturalTaskPolicy.edit_allowed?(user, is_reference: task.is_reference, user_id: task.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          task
        end

        def find_authorized_for_view(user, id)
          Adapters::AgriculturalTask::Mappers::AgriculturalTaskMapper.agricultural_task_entity_from_record(find_authorized_model_for_view(user, id))
        end

        def find_authorized_for_edit(user, id)
          Adapters::AgriculturalTask::Mappers::AgriculturalTaskMapper.agricultural_task_entity_from_record(find_authorized_model_for_edit(user, id))
        end

        def find_model(id)
          find_agricultural_task_model!(id)
        end

        def create_for_user(user, attrs)
          h = Domain::Shared::Policies::AgriculturalTaskPolicy.normalize_attrs_for_create(user, attrs)
          task = ::AgriculturalTask.new(h)
          raise StandardError, task.errors.full_messages.join(", ") unless task.save

          Adapters::AgriculturalTask::Mappers::AgriculturalTaskMapper.agricultural_task_entity_from_record(task)
        end

        def update_for_user(user, id, attrs)
          task = find_agricultural_task_model!(id)
          unless Domain::Shared::Policies::AgriculturalTaskPolicy.edit_allowed?(user, is_reference: task.is_reference, user_id: task.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          normalized = Domain::Shared::Policies::AgriculturalTaskPolicy.normalize_attrs_for_update(
            user,
            task.attributes.symbolize_keys,
            attrs
          )
          raise StandardError, task.errors.full_messages.join(", ") unless task.update(normalized)

          Adapters::AgriculturalTask::Mappers::AgriculturalTaskMapper.agricultural_task_entity_from_record(task.reload)
        end

        def soft_destroy_with_undo(user:, task_id:, auto_hide_after: 5000, translator: nil)
          translator ||= @translator
          translator ||= Adapters::Translators::RailsTranslator.new
          task = find_agricultural_task_model!(task_id)
          unless Domain::Shared::Policies::AgriculturalTaskPolicy.edit_allowed?(user, is_reference: task.is_reference, user_id: task.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          name = task.name
          toast_message = translator.t("agricultural_tasks.undo.toast", name: name)
          undo_gw = Domain::DeletionUndo::Gateways::DeletionUndoGateway.default
          event = undo_gw.schedule(
            record: task,
            actor: user,
            toast_message: toast_message,
            auto_hide_after: auto_hide_after
          )
          { success: true, undo_entity: event, resource_name: name }
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          raise
        rescue StandardError => e
          { success: false, error_dto: Domain::Shared::Dtos::ErrorDto.new(e.message) }
        end

        def recent_for_user(user, limit: nil)
          scope = visible_records(user).recent
          limit ? scope.limit(limit) : scope
        end

        def any_visible_for_user?(user)
          visible_records(user).exists?
        end

        def all_records_relation
          ::AgriculturalTask.all
        end

        private

        def find_agricultural_task_model!(id)
          ::AgriculturalTask.find(id)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end
      end
    end
  end
end
