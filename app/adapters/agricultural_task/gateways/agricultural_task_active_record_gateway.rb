# frozen_string_literal: true

module Adapters
  module AgriculturalTask
    module Gateways
      class AgriculturalTaskActiveRecordGateway < Domain::AgriculturalTask::Gateways::AgriculturalTaskGateway
        attr_accessor :translator

        def initialize(deletion_undo_gateway:, sql_like_sanitize_port:, translator:)
          @deletion_undo_gateway = deletion_undo_gateway
          @sql_like_sanitize_port = sql_like_sanitize_port
          @translator = translator
        end

        def list_user_owned_tasks(user_id:, query: nil)
          scope = ::AgriculturalTask.where(user_id: user_id, is_reference: false)
          scope = apply_search_scope(scope, query) if Domain::Shared::ValidationHelpers.present?(query)
          scope.recent.map { |record| Adapters::AgriculturalTask::Mappers::AgriculturalTaskMapper.agricultural_task_entity_from_record(record) }
        end

        def list_for_index(user:, is_admin:, filter: nil, query: nil)
          scope = if is_admin
                    case filter
                    when "user"
                      ::AgriculturalTask.where(user_id: user.id, is_reference: false)
                    when "reference"
                      ::AgriculturalTask.where(is_reference: true)
                    else
                      # デフォルト（"all" または nil）: 参照タスクと自分のユーザータスクの両方
                      ::AgriculturalTask.where("is_reference = ? OR user_id = ?", true, user.id)
                    end
                  else
                    ::AgriculturalTask.where(user_id: user.id, is_reference: false)
                  end
          scope = apply_search_scope(scope, query) if Domain::Shared::ValidationHelpers.present?(query)
          scope.recent.map { |record| Adapters::AgriculturalTask::Mappers::AgriculturalTaskMapper.agricultural_task_entity_from_record(record) }
        end

        def reference_tasks_for_index(is_admin:)
          return [] unless is_admin

          ::AgriculturalTask.where(is_reference: true).recent.map { |record| Adapters::AgriculturalTask::Mappers::AgriculturalTaskMapper.agricultural_task_entity_from_record(record) }
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

        def authorized_agricultural_task_detail_output(user, id, access_filter:)
          task = ::AgriculturalTask.includes(:crops).find(id)
          unless access_filter.view_allows?(is_reference: task.is_reference, record_user_id: task.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          Adapters::AgriculturalTask::Mappers::AgriculturalTaskMapper.detail_output_dto_from_record(task)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def find_authorized_for_edit(user, id, access_filter:)
          Adapters::AgriculturalTask::Mappers::AgriculturalTaskMapper.agricultural_task_entity_from_record(find_authorized_task_model_for_edit(user, id, access_filter: access_filter))
        end

        def find_authorized_agricultural_task_loaded_bundle!(user, id, for_edit:, access_filter:)
          task = if for_edit
                   find_authorized_task_model_for_edit(user, id, access_filter: access_filter)
                 else
                   find_authorized_task_model_for_view(user, id, access_filter: access_filter)
                 end
          Domain::AgriculturalTask::Dtos::AuthorizedAgriculturalTaskLoaded.new(
            agricultural_task_entity: Adapters::AgriculturalTask::Mappers::AgriculturalTaskMapper.agricultural_task_entity_from_record(task),
            master_form_snapshot: Adapters::AgriculturalTask::Mappers::AgriculturalTaskMasterFormSnapshotMapper.from_record(task)
          )
        end

        def find_by_id(id)
          Adapters::AgriculturalTask::Mappers::AgriculturalTaskMapper.agricultural_task_entity_from_record(find_agricultural_task_model!(id))
        end

        def create_for_user(user, attrs)
          task = ::AgriculturalTask.new(attrs.to_h.symbolize_keys)
          raise Domain::Shared::Exceptions::RecordInvalid, task.errors.full_messages.join(", ") unless task.save

          Adapters::AgriculturalTask::Mappers::AgriculturalTaskMapper.agricultural_task_entity_from_record(task)
        end

        # @param selected_crop_ids [Array<Integer>, nil] nil なら CropTaskTemplate の同期をスキップ
        def update_for_user(user, id, attrs, access_filter:, selected_crop_ids: nil)
          ::ActiveRecord::Base.transaction do
            task = find_agricultural_task_model!(id)
            unless access_filter.edit_allows?(is_reference: task.is_reference, record_user_id: task.user_id)
              raise Domain::Shared::Policies::PolicyPermissionDenied
            end

            raise Domain::Shared::Exceptions::RecordInvalid, task.errors.full_messages.join(", ") unless task.update(attrs.to_h.symbolize_keys)

            task.reload
            sync_crop_task_templates_for_task!(task, selected_crop_ids) unless selected_crop_ids.nil?

            Adapters::AgriculturalTask::Mappers::AgriculturalTaskMapper.agricultural_task_entity_from_record(task.reload)
          end
        end

        def soft_delete_with_undo(user:, task_id:, auto_hide_after: 5000, translator:, access_filter:)
          task = find_agricultural_task_model!(task_id)
          unless access_filter.edit_allows?(is_reference: task.is_reference, record_user_id: task.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          name = task.name
          toast_message = translator.t("agricultural_tasks.undo.toast", name: name)
          undo_gw = @deletion_undo_gateway
          event = undo_gw.schedule(
            resource_type: task.class.name,
            resource_id: task.id,
            actor_id: user.id,
            toast_message: toast_message,
            auto_hide_after: auto_hide_after
          )
          { success: true, undo_entity: event, resource_name: name }
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          raise
        rescue Domain::Shared::Exceptions::RecordNotFound
          raise
        rescue StandardError => e
          { success: false, error_dto: Domain::Shared::Dtos::Error.new(e.message) }
        end

        def linked_crop_ids_for_task_templates(agricultural_task_id)
          return [] if agricultural_task_id.blank?

          ::CropTaskTemplate.where(agricultural_task_id: agricultural_task_id.to_i).pluck(:crop_id)
        end

        def build_blank_agricultural_task_for_master_form(user)
          ::AgriculturalTask.new(user_id: user.id, is_reference: false)
        end

        def build_after_create_failure_agricultural_task_for_master_form!(user:, attributes:)
          sym = attributes.respond_to?(:symbolize_keys) ? attributes.symbolize_keys : attributes.to_h.symbolize_keys
          task = ::AgriculturalTask.new(
            user_id: user.id,
            name: sym[:name],
            description: sym[:description],
            time_per_sqm: sym[:time_per_sqm],
            weather_dependency: sym[:weather_dependency],
            skill_level: sym[:skill_level],
            is_reference: sym[:is_reference],
            required_tools: sym[:required_tools],
            region: sym[:region]
          )
          task.valid?
          task
        end

        def merge_update_form_snapshot_for_master_form!(user:, task_id:, dto:, task_attributes:, access_filter:)
          task = find_authorized_task_model_for_edit(user, task_id.to_i, access_filter: access_filter)
          ta = task_attributes.respond_to?(:symbolize_keys) ? task_attributes.symbolize_keys : task_attributes.to_h.symbolize_keys
          task.assign_attributes(
            name: dto.name || ta[:name],
            description: dto.description || ta[:description],
            time_per_sqm: dto.time_per_sqm || ta[:time_per_sqm],
            weather_dependency: dto.weather_dependency || ta[:weather_dependency],
            skill_level: dto.skill_level || ta[:skill_level],
            is_reference: dto.is_reference.nil? ? ta[:is_reference] : dto.is_reference,
            required_tools: dto.required_tools || ta[:required_tools],
            region: dto.region || ta[:region]
          )
          task.valid?
          task
        end

        def preview_agricultural_task_for_edit_crop_selection(base_entity:, user:, agricultural_task_params:)
          requested_flag = preview_requested_reference_flag(base_entity, agricultural_task_params)
          return base_entity if requested_flag == base_entity.is_reference?

          new_user_id = preview_user_id_after_reference_toggle(base_entity: base_entity, user: user, reference_flag: requested_flag)
          Domain::AgriculturalTask::Entities::AgriculturalTaskEntity.new(
            base_entity.to_hash.merge(is_reference: requested_flag, user_id: new_user_id)
          )
        end

        private

        def find_authorized_task_model_for_view(user, id, access_filter:)
          task = find_agricultural_task_model!(id)
          unless access_filter.view_allows?(is_reference: task.is_reference, record_user_id: task.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          task
        end

        def find_authorized_task_model_for_edit(user, id, access_filter:)
          task = find_agricultural_task_model!(id)
          unless access_filter.edit_allows?(is_reference: task.is_reference, record_user_id: task.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          task
        end

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

        # HTML 更新フローでコントローラが担っていた作物テンプレート同期（AR は本アダプタに閉じる）
        def sync_crop_task_templates_for_task!(task, selected_crop_ids)
          allowed_crop_ids = allowed_crop_ids_for_template_sync(task, selected_crop_ids)
          current_template_crop_ids = ::CropTaskTemplate.where(agricultural_task: task).pluck(:crop_id)

          crops_to_add = allowed_crop_ids - current_template_crop_ids
          crops_to_add.each do |crop_id|
            crop = ::Crop.find_by(id: crop_id)
            next unless crop

            next if ::CropTaskTemplate.exists?(crop: crop, agricultural_task: task)

            crop.crop_task_templates.create!(
              agricultural_task: task,
              name: task.name,
              description: task.description,
              time_per_sqm: task.time_per_sqm,
              weather_dependency: task.weather_dependency,
              required_tools: task.required_tools,
              skill_level: task.skill_level
            )
          end

          crops_to_remove = current_template_crop_ids - allowed_crop_ids
          crops_to_remove.each do |crop_id|
            crop = ::Crop.find_by(id: crop_id)
            next unless crop

            template = ::CropTaskTemplate.find_by(crop: crop, agricultural_task: task)
            template&.destroy
          end
        rescue ActiveRecord::RecordInvalid => e
          raise Domain::Shared::Exceptions::RecordInvalid, e.record.errors.full_messages.join(", ")
        rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::RecordNotSaved => e
          raise Domain::Shared::Exceptions::RecordInvalid, e.message
        rescue ActiveRecord::StatementInvalid => e
          raise Domain::Shared::Exceptions::RecordInvalid, e.message
        end

        def allowed_crop_ids_for_template_sync(task, selected_crop_ids)
          scope =
            if task.is_reference?
              ::Crop.where(is_reference: true)
            else
              ::Crop.where(is_reference: false, user_id: task.user_id)
            end

          scope = scope.where(region: task.region) if task.region.present?

          scope.where(id: Array(selected_crop_ids).map(&:to_i).uniq).pluck(:id)
        end

        def preview_requested_reference_flag(base_entity, attributes)
          return base_entity.is_reference? unless attributes.respond_to?(:key?) && attributes.key?(:is_reference)

          casted = ActiveModel::Type::Boolean.new.cast(attributes[:is_reference])
          casted.nil? ? false : casted
        end

        def preview_user_id_after_reference_toggle(base_entity:, user:, reference_flag:)
          return nil if reference_flag

          base_entity.user_id.presence || user.id
        end
      end
    end
  end
end
