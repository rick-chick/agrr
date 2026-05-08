# frozen_string_literal: true

module Adapters
  module Crop
    module Gateways
      class CropMemoryGateway < Domain::Crop::Gateways::CropGateway
        def initialize(deletion_undo_gateway:)
          @deletion_undo_gateway = deletion_undo_gateway
        end

        def list_index_for_user(user)
          query = index_scope_for_user(user)
          query.map { |record| Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(record) }
        end

        def list_user_owned_non_reference_crops_ordered_by_name(user)
          user_owned_non_reference_scope(user).order(:name).map { |record| Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(record) }
        end

        def list_non_reference_crops_for_user_id_ordered(user_id, region = nil)
          return [] if user_id.blank?

          scope = ::Crop.where(is_reference: false, user_id: user_id)
          scope = scope.where(region: region) if region.present?
          scope.order(:name).map { |record| Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(record) }
        end

        def find_user_non_reference_crop_for_masters!(user, crop_id)
          user_owned_non_reference_scope(user).find(crop_id)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def find_user_non_reference_crop_record(user, crop_id)
          user_owned_non_reference_scope(user).find_by(id: crop_id)
        end

        def find_reference_crop_record_for_public_plan_add_crop(crop_id)
          return nil if crop_id.blank?

          ::Crop.reference.find_by(id: crop_id.to_i)
        end

        def list_reference_crop_entities(region: nil)
          scope = ::Crop.reference
          scope = scope.where(region: region) if region.present?
          scope.order(:name).map { |record| Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(record) }
        end

        def each_reference_crop_for_entry_schedule(region)
          ::Crop.reference
            .yield_self { |s| region.present? ? s.where(region: region) : s }
            .includes(crop_stages: :temperature_requirement)
            .order(:name)
            .find_each { |crop| yield crop }
        end

        def find_reference_crop_for_entry_schedule!(region, crop_id)
          scope = ::Crop.reference
          scope = scope.where(region: region) if region.present?
          scope.includes(crop_stages: :temperature_requirement).find(crop_id)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        CROP_ASSOCIATION_PRELOAD_INCLUDES = {
          crop_stages: [ :temperature_requirement, :thermal_requirement, :sunshine_requirement, :nutrient_requirement ],
          agricultural_tasks: [],
          crop_task_templates: [ :agricultural_task ],
          crop_task_schedule_blueprints: [ :agricultural_task ]
        }.freeze

        def find_authorized_model_for_view(user, id)
          crop = find_crop_model!(id)
          unless Domain::Shared::Policies::CropPolicy.view_allowed?(user, is_reference: crop.is_reference, user_id: crop.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          crop
        end

        def find_authorized_model_for_edit(user, id)
          crop = find_crop_model!(id)
          unless Domain::Shared::Policies::CropPolicy.edit_allowed?(user, is_reference: crop.is_reference, user_id: crop.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          crop
        end

        def find_authorized_for_view(user, id)
          Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(find_authorized_model_for_view(user, id))
        end

        def find_authorized_for_edit(user, id)
          Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(find_authorized_model_for_edit(user, id))
        end

        def find_authorized_crop_loaded_bundle!(user, id, for_edit:)
          crop = authorized_crop_record_with_association_preloads!(user, id, for_edit: for_edit)

          Domain::Crop::Dtos::AuthorizedCropLoadedDto.new(
            crop_entity: Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(crop),
            persisted_crop: crop
          )
        end

        def build_blank_crop_for_html_form
          ::Crop.new
        end

        def build_new_crop_with_attributes_for_html_form(attributes:)
          ::Crop.new(attributes)
        end

        def prepare_crop_record_for_edit_html_form!(crop)
          crop.crop_stages.each do |stage|
            stage.build_nutrient_requirement unless stage.nutrient_requirement
          end
        end

        def merge_edit_crop_params_for_html_form!(user:, crop_id:, attributes:)
          bundle = find_authorized_crop_loaded_bundle!(user, crop_id, for_edit: true)
          crop = bundle.persisted_crop
          crop.assign_attributes(attributes)
          crop
        end

        def find_masters_crop_with_crop_stage_bundle!(user, crop_id, crop_stage_id)
          crop = find_user_non_reference_crop_for_masters!(user, crop_id)
          stage = crop.crop_stages.find(crop_stage_id)
          Domain::Crop::Dtos::AuthorizedCropStageInCropContextDto.new(
            persisted_crop: crop,
            persisted_crop_stage: stage
          )
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "CropStage not found"
        end

        def find_masters_crop_with_task_template_bundle!(user, crop_id, template_id)
          crop = find_user_non_reference_crop_for_masters!(user, crop_id)
          tpl = crop.crop_task_templates.find(template_id)
          Domain::Crop::Dtos::AuthorizedCropTaskTemplateInCropContextDto.new(
            persisted_crop: crop,
            persisted_crop_task_template: tpl
          )
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "AgriculturalTask association not found"
        end

        def create_masters_crop_task_template_association(user, input_dto)
          crop = find_user_non_reference_crop_for_masters!(user, input_dto.crop_id.to_i)
          agricultural_task = ::AgriculturalTask.find_by(id: input_dto.agricultural_task_id)
          unless agricultural_task
            return build_task_template_create_result(reason: :agricultural_task_not_found)
          end

          unless Domain::Shared::Policies::AgriculturalTaskPolicy.masters_crop_task_template_associate_allowed?(
            user,
            is_reference: agricultural_task.is_reference,
            user_id: agricultural_task.user_id
          )
            return build_task_template_create_result(reason: :forbidden)
          end

          existing_template = crop.crop_task_templates.find_by(agricultural_task_id: agricultural_task.id)
          if existing_template
            return build_task_template_create_result(reason: :duplicate)
          end

          template_params = {
            agricultural_task: agricultural_task,
            name: input_dto.name.nil? ? agricultural_task.name : input_dto.name,
            description: input_dto.description.nil? ? agricultural_task.description : input_dto.description,
            time_per_sqm: input_dto.time_per_sqm.nil? ? agricultural_task.time_per_sqm : input_dto.time_per_sqm,
            weather_dependency: input_dto.weather_dependency.nil? ? agricultural_task.weather_dependency : input_dto.weather_dependency,
            required_tools: input_dto.required_tools.nil? ? (agricultural_task.required_tools || []) : input_dto.required_tools,
            skill_level: input_dto.skill_level.nil? ? agricultural_task.skill_level : input_dto.skill_level
          }

          template = crop.crop_task_templates.create!(template_params)
          task_snapshot = agricultural_task_snapshot_from_record(agricultural_task)
          template_dto = masters_crop_task_template_dto_from_record(template, task_snapshot)
          Domain::Crop::Dtos::MastersCropTaskTemplateCreateResultDto.new(template: template_dto)
        rescue Domain::Shared::Exceptions::RecordNotFound
          build_task_template_create_result(reason: :crop_not_found)
        rescue ActiveRecord::RecordInvalid => e
          raise Domain::Shared::Exceptions::RecordInvalid.new(e.message, errors: Domain::Shared::ValidationErrors.from_errors_like(e.record.errors))
        end

        def masters_crop_agricultural_task_templates_index_rows(user:, crop_id:)
          crop = find_user_non_reference_crop_for_masters!(user, crop_id.to_i)
          crop.crop_task_templates.includes(:agricultural_task).map { |t| masters_crop_task_template_api_row(t) }
        end

        def selectable_agricultural_task_picklist_rows_for_nested_templates(user:, crop_id:)
          crop = find_user_non_reference_crop_for_masters!(user, crop_id.to_i)
          scope = ::AgriculturalTask.where("is_reference = ? OR user_id = ?", true, user.id)
          existing_task_ids = crop.crop_task_templates.pluck(:agricultural_task_id).compact
          scope = scope.where.not(id: existing_task_ids) if existing_task_ids.any?
          scope.recent.map { |t| { id: t.id, name: t.name } }
        end

        def update_masters_crop_task_template_for_api(user:, crop_id:, template_id:, attributes:)
          bundle = find_masters_crop_with_task_template_bundle!(user, crop_id.to_i, template_id.to_i)
          tpl = bundle.persisted_crop_task_template
          if tpl.update(attributes)
            { ok: true, row: masters_crop_task_template_api_row(tpl.reload) }
          else
            { ok: false, errors: tpl.errors.full_messages }
          end
        end

        def destroy_masters_crop_task_template_for_api!(user:, crop_id:, template_id:)
          bundle = find_masters_crop_with_task_template_bundle!(user, crop_id.to_i, template_id.to_i)
          bundle.persisted_crop_task_template.destroy!
          :ok
        end

        def find_authorized_crop_with_crop_stage_bundle!(user, crop_id, crop_stage_id, for_edit:)
          crop = if for_edit
                   find_authorized_model_for_edit(user, crop_id)
                 else
                   find_authorized_model_for_view(user, crop_id)
                 end
          stage = crop.crop_stages.find(crop_stage_id)
          Domain::Crop::Dtos::AuthorizedCropStageInCropContextDto.new(
            persisted_crop: crop,
            persisted_crop_stage: stage
          )
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "CropStage not found"
        end

        def find_authorized_crop_task_template_in_crop!(user, crop_id, template_id, for_edit:)
          crop = if for_edit
                   find_authorized_model_for_edit(user, crop_id)
                 else
                   find_authorized_model_for_view(user, crop_id)
                 end
          tpl = crop.crop_task_templates.find(template_id)
          Domain::Crop::Dtos::AuthorizedCropTaskTemplateInCropContextDto.new(
            persisted_crop: crop,
            persisted_crop_task_template: tpl
          )
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound
        end

        def delete_task_schedule_blueprint_bundle_in_crop!(user, crop_id, blueprint_id)
          crop = find_authorized_model_for_edit(user, crop_id)
          bp = crop.crop_task_schedule_blueprints.find(blueprint_id)
          blueprint_id_for_response = bp.id
          result = ::Crops::TaskScheduleBlueprintDeletionService.new(crop: crop, blueprint: bp).call
          crop.reload
          result.merge(crop: crop, blueprint_id_for_response: blueprint_id_for_response)
        rescue ActiveRecord::RecordNotFound
          { not_found: true, blueprint_deleted: false, template_deleted: false }
        end

        # Crops::TaskScheduleBlueprintsController 用: 位置更新と priority 再採番（AR 境界例外は本メソッド内で吸収）
        # @return [Hash] :ok (boolean), :status (Symbol), :payload (Hash on success), :error (String on failure)
        def update_task_schedule_blueprint_position_mutation(crop:, blueprint:, gdd_trigger:, priority:)
          blueprint.gdd_trigger = gdd_trigger if gdd_trigger
          blueprint.priority = priority if priority

          unless blueprint.save
            return {
              ok: false,
              status: :unprocessable_entity,
              error: blueprint.errors.full_messages.join(", ")
            }
          end

          reorder_crop_task_schedule_blueprint_priorities!(crop)
          blueprint.reload

          {
            ok: true,
            status: :ok,
            payload: {
              id: blueprint.id,
              gdd_trigger: blueprint.gdd_trigger.to_f,
              priority: blueprint.priority,
              message: I18n.t("crops.flash.blueprint_position_updated")
            }
          }
        rescue ActiveRecord::StatementInvalid,
               ActiveRecord::ConnectionNotEstablished,
               ActiveRecord::RecordNotDestroyed,
               JSON::GeneratorError,
               ActionView::Template::Error => e
          Rails.logger.error("❌ [CropMemoryGateway] Failed to update blueprint position: #{e.class} #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
          { ok: false, status: :internal_server_error, error: I18n.t("crops.flash.blueprint_update_failed") }
        end

        def update_task_schedule_blueprint_position_for_user(user:, crop_id:, blueprint_id:, gdd_trigger:, priority:)
          crop = find_authorized_model_for_edit(user, crop_id.to_i)
          bp = crop.crop_task_schedule_blueprints.find(blueprint_id.to_i)
          update_task_schedule_blueprint_position_mutation(crop: crop, blueprint: bp, gdd_trigger: gdd_trigger, priority: priority)
        rescue ActiveRecord::RecordNotFound
          { ok: false, status: :not_found, error: I18n.t("crops.flash.blueprint_not_found") }
        end

        # ブループリント削除後の crop 再読込と UI 用タスク一覧（レンダリング前の失敗を吸収）
        def reload_crop_after_task_schedule_blueprint_delete!(crop:, blueprint_id_for_response:)
          crop.reload
          available = available_agricultural_tasks_for_crop(crop)
          selected_ids = crop.crop_task_templates.pluck(:agricultural_task_id).compact.uniq
          {
            ok: true,
            crop: crop,
            available_agricultural_tasks: available,
            selected_task_ids: selected_ids,
            blueprint_id_for_response: blueprint_id_for_response
          }
        rescue ActiveRecord::StatementInvalid,
               ActiveRecord::ConnectionNotEstablished,
               ActiveRecord::RecordNotDestroyed,
               ActiveRecord::RecordInvalid,
               JSON::GeneratorError,
               ActionView::Template::Error => e
          Rails.logger.error("❌ [CropMemoryGateway] Failed after blueprint delete: #{e.class} #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
          { ok: false, blueprint_id_for_response: blueprint_id_for_response }
        end

        def find_authorized_crop_show_detail(user, crop_id)
          crop = authorized_crop_record_with_association_preloads!(user, crop_id, for_edit: false)
          task_schedule_blueprints = crop.crop_task_schedule_blueprints
                                          .includes(:agricultural_task)
                                          .ordered
          available_tasks = available_agricultural_tasks_for_crop(crop)
          selected_task_ids = crop.crop_task_templates.pluck(:agricultural_task_id).compact.uniq

          Domain::Crop::Dtos::CropDetailOutputDto.new(
            crop: Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(crop),
            persisted_crop: crop,
            task_schedule_blueprints: task_schedule_blueprints,
            available_agricultural_tasks: available_tasks,
            selected_task_ids: selected_task_ids
          )
        end

        def find_model(id)
          find_crop_model!(id)
        end

        def entry_schedule_ordered_stage_rows(crop_id:)
          crop = ::Crop.includes(crop_stages: :temperature_requirement).find(crop_id)
          crop.crop_stages.sort_by(&:order).map do |st|
            tr = st.temperature_requirement
            snap_tr = tr && Domain::CultivationPlan::Interactors::EntrySchedule::TemperatureRequirementSnapshot.new(
              frost_threshold: tr.frost_threshold,
              optimal_min: tr.optimal_min,
              optimal_max: tr.optimal_max,
              base_temperature: tr.base_temperature
            )
            Domain::CultivationPlan::Interactors::EntrySchedule::CropStageSnapshot.new(
              id: st.id,
              name: st.name,
              order: st.order,
              temperature_requirement: snap_tr
            )
          end
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def create_for_user(user, attrs)
          h = Domain::Shared::Policies::CropPolicy.normalize_attrs_for_create(user, attrs)
          crop = ::Crop.new(h)
          raise Domain::Shared::Exceptions::RecordInvalid, crop.errors.full_messages.join(", ") unless crop.save

          Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(crop)
        end

        def update_for_user(user, id, attrs)
          crop = find_crop_model!(id)
          unless Domain::Shared::Policies::CropPolicy.edit_allowed?(user, is_reference: crop.is_reference, user_id: crop.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          normalized = Domain::Shared::Policies::CropPolicy.normalize_attrs_for_update(
            user,
            crop.attributes.symbolize_keys,
            attrs
          )
          raise Domain::Shared::Exceptions::RecordInvalid, crop.errors.full_messages.join(", ") unless crop.update(normalized)

          Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(crop.reload)
        end

        def soft_destroy_with_undo(user:, crop_id:, auto_hide_after: 5000, translator:)
          crop = find_crop_model!(crop_id)
          unless Domain::Shared::Policies::CropPolicy.edit_allowed?(user, is_reference: crop.is_reference, user_id: crop.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          if crop.cultivation_plan_crops.any?
            return { success: false, error_dto: Domain::Shared::Dtos::ErrorDto.new(translator.t("crops.flash.cannot_delete_in_use.plan")) }
          end
          if crop.free_crop_plans.any?
            return { success: false, error_dto: Domain::Shared::Dtos::ErrorDto.new(translator.t("crops.flash.cannot_delete_in_use.other")) }
          end
          if crop.pesticides.any?
            return { success: false, error_dto: Domain::Shared::Dtos::ErrorDto.new(translator.t("crops.flash.cannot_delete_in_use.other")) }
          end
          toast_message = translator.t("crops.undo.toast", name: crop.name)
          undo_gw = @deletion_undo_gateway
          event = undo_gw.schedule(
            resource_type: crop.class.name,
            resource_id: crop.id,
            actor_id: user.id,
            toast_message: toast_message,
            auto_hide_after: auto_hide_after
          )
          { success: true, undo_entity: event }
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          raise
        rescue Domain::Shared::Exceptions::RecordNotFound
          raise
        rescue StandardError => e
          { success: false, error_dto: Domain::Shared::Dtos::ErrorDto.new(e.message) }
        end

        # CropStage methods
        def create_crop_stage(create_dto)
          crop_stage_attributes = attributes_from_crop_stage_dto(create_dto.payload)
          crop_stage_attributes[:crop_id] = create_dto.crop_id

          crop_stage = ::CropStage.new(crop_stage_attributes)
          unless crop_stage.save
            raise Domain::Shared::Exceptions::RecordInvalid, crop_stage.errors.full_messages.join(", ")
          end
          crop_stage_entity_from_record(crop_stage)
        end

        def update_crop_stage(crop_stage_id, update_dto)
          crop_stage = ::CropStage.find(crop_stage_id)
          attrs = attributes_from_crop_stage_dto(update_dto.payload)

          unless crop_stage.update(attrs)
            raise Domain::Shared::Exceptions::RecordInvalid, crop_stage.errors.full_messages.join(", ")
          end
          crop_stage_entity_from_record(crop_stage.reload)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "CropStage not found"
        end

        def delete_crop_stage(crop_stage_id)
          crop_stage = ::CropStage.find(crop_stage_id)
          unless crop_stage.destroy
            raise Domain::Shared::Exceptions::RecordInvalid, crop_stage.errors.full_messages.join(", ")
          end
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "CropStage not found"
        end

        def list_crop_stages_by_crop_id(crop_id)
          crop_stages = ::CropStage.where(crop_id: crop_id).order(:order)
          crop_stages.map { |record| crop_stage_entity_from_record(record) }
        end

        def find_crop_stage_by_id(crop_stage_id)
          crop_stage = ::CropStage.find(crop_stage_id)
          crop_stage_entity_from_record(crop_stage)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "CropStage not found"
        end

        # TemperatureRequirement methods
        def find_temperature_requirement(crop_stage_id)
          requirement = ::TemperatureRequirement.find_by(crop_stage_id: crop_stage_id)
          return nil unless requirement
          temperature_requirement_entity_from_record(requirement)
        end

        def create_temperature_requirement(crop_stage_id, requirement_dto)
          attrs = attributes_from_temperature_requirement_dto(requirement_dto.payload)
          attrs[:crop_stage_id] = crop_stage_id

          requirement = ::TemperatureRequirement.new(attrs)
          unless requirement.save
            raise_record_invalid_for_model!(requirement)
          end
          temperature_requirement_entity_from_record(requirement)
        end

        def update_temperature_requirement(crop_stage_id, requirement_dto)
          requirement = ::TemperatureRequirement.find_by!(crop_stage_id: crop_stage_id)
          attrs = attributes_from_temperature_requirement_dto(requirement_dto.payload)

          unless requirement.update(attrs)
            raise_record_invalid_for_model!(requirement)
          end
          temperature_requirement_entity_from_record(requirement.reload)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "TemperatureRequirement not found"
        end

        def destroy_temperature_requirement(crop_stage_id)
          requirement = ::TemperatureRequirement.find_by(crop_stage_id: crop_stage_id)
          unless requirement
            raise Domain::Shared::Exceptions::RecordNotFound, "TemperatureRequirement not found"
          end

          unless requirement.destroy
            raise_record_invalid_for_model!(requirement)
          end
        end

        # ThermalRequirement methods
        def find_thermal_requirement(crop_stage_id)
          requirement = ::ThermalRequirement.find_by(crop_stage_id: crop_stage_id)
          return nil unless requirement
          thermal_requirement_entity_from_record(requirement)
        end

        def create_thermal_requirement(crop_stage_id, requirement_dto)
          attrs = attributes_from_thermal_requirement_dto(requirement_dto.payload)
          attrs[:crop_stage_id] = crop_stage_id

          requirement = ::ThermalRequirement.new(attrs)
          unless requirement.save
            raise_record_invalid_for_model!(requirement)
          end
          thermal_requirement_entity_from_record(requirement)
        end

        def update_thermal_requirement(crop_stage_id, requirement_dto)
          requirement = ::ThermalRequirement.find_by!(crop_stage_id: crop_stage_id)
          attrs = attributes_from_thermal_requirement_dto(requirement_dto.payload)

          unless requirement.update(attrs)
            raise_record_invalid_for_model!(requirement)
          end
          thermal_requirement_entity_from_record(requirement.reload)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "ThermalRequirement not found"
        end

        def destroy_thermal_requirement(crop_stage_id)
          requirement = ::ThermalRequirement.find_by(crop_stage_id: crop_stage_id)
          unless requirement
            raise Domain::Shared::Exceptions::RecordNotFound, "ThermalRequirement not found"
          end

          unless requirement.destroy
            raise_record_invalid_for_model!(requirement)
          end
        end

        # SunshineRequirement methods
        def find_sunshine_requirement(crop_stage_id)
          requirement = ::SunshineRequirement.find_by(crop_stage_id: crop_stage_id)
          return nil unless requirement
          sunshine_requirement_entity_from_record(requirement)
        end

        def create_sunshine_requirement(crop_stage_id, requirement_dto)
          attrs = attributes_from_sunshine_requirement_dto(requirement_dto.payload)
          attrs[:crop_stage_id] = crop_stage_id

          requirement = ::SunshineRequirement.new(attrs)
          unless requirement.save
            raise_record_invalid_for_model!(requirement)
          end
          sunshine_requirement_entity_from_record(requirement)
        end

        def update_sunshine_requirement(crop_stage_id, requirement_dto)
          requirement = ::SunshineRequirement.find_by!(crop_stage_id: crop_stage_id)
          attrs = attributes_from_sunshine_requirement_dto(requirement_dto.payload)

          unless requirement.update(attrs)
            raise_record_invalid_for_model!(requirement)
          end
          sunshine_requirement_entity_from_record(requirement.reload)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "SunshineRequirement not found"
        end

        def destroy_sunshine_requirement(crop_stage_id)
          requirement = ::SunshineRequirement.find_by(crop_stage_id: crop_stage_id)
          unless requirement
            raise Domain::Shared::Exceptions::RecordNotFound, "SunshineRequirement not found"
          end

          unless requirement.destroy
            raise_record_invalid_for_model!(requirement)
          end
        end

        # NutrientRequirement methods
        def find_nutrient_requirement(crop_stage_id)
          requirement = ::NutrientRequirement.find_by(crop_stage_id: crop_stage_id)
          return nil unless requirement
          nutrient_requirement_entity_from_record(requirement)
        end

        def create_nutrient_requirement(crop_stage_id, requirement_dto)
          attrs = attributes_from_nutrient_requirement_dto(requirement_dto.payload)
          attrs[:crop_stage_id] = crop_stage_id

          requirement = ::NutrientRequirement.new(attrs)
          unless requirement.save
            raise_record_invalid_for_model!(requirement)
          end
          nutrient_requirement_entity_from_record(requirement)
        end

        def update_nutrient_requirement(crop_stage_id, requirement_dto)
          requirement = ::NutrientRequirement.find_by!(crop_stage_id: crop_stage_id)
          attrs = attributes_from_nutrient_requirement_dto(requirement_dto.payload)

          unless requirement.update(attrs)
            raise_record_invalid_for_model!(requirement)
          end
          nutrient_requirement_entity_from_record(requirement.reload)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "NutrientRequirement not found"
        end

        def destroy_nutrient_requirement(crop_stage_id)
          requirement = ::NutrientRequirement.find_by(crop_stage_id: crop_stage_id)
          unless requirement
            raise Domain::Shared::Exceptions::RecordNotFound, "NutrientRequirement not found"
          end

          unless requirement.destroy
            raise_record_invalid_for_model!(requirement)
          end
        end

        private

        def raise_record_invalid_for_model!(record)
          raise Domain::Shared::Exceptions::RecordInvalid.new(
            record.errors.full_messages.join(", "),
            errors: Domain::Shared::ValidationErrors.from_errors_like(record.errors)
          )
        end

        def build_task_template_create_result(reason:)
          Domain::Crop::Dtos::MastersCropTaskTemplateCreateResultDto.new(
            failure: Domain::Crop::Dtos::MastersCropTaskTemplateCreateFailureDto.new(
              reason: reason
            )
          )
        end

        def agricultural_task_snapshot_from_record(record)
          return nil unless record

          Domain::Crop::Dtos::AgriculturalTaskSnapshotDto.new(
            id: record.id,
            name: record.name,
            description: record.description,
            is_reference: record.is_reference
          )
        end

        def masters_crop_task_template_dto_from_record(template, task_snapshot)
          Domain::Crop::Dtos::MastersCropTaskTemplateDto.new(
            id: template.id,
            crop_id: template.crop_id,
            agricultural_task_id: template.agricultural_task_id,
            name: template.name,
            description: template.description,
            time_per_sqm: template.time_per_sqm,
            weather_dependency: template.weather_dependency,
            required_tools: template.required_tools || [],
            skill_level: template.skill_level,
            agricultural_task: task_snapshot,
            created_at: template.created_at,
            updated_at: template.updated_at
          )
        end

        def masters_crop_task_template_api_row(template)
          at = template.agricultural_task
          {
            id: template.id,
            crop_id: template.crop_id,
            agricultural_task_id: template.agricultural_task_id,
            name: template.name,
            description: template.description,
            time_per_sqm: template.time_per_sqm,
            weather_dependency: template.weather_dependency,
            required_tools: template.required_tools || [],
            skill_level: template.skill_level,
            agricultural_task: at ? {
              id: at.id,
              name: at.name,
              description: at.description,
              is_reference: at.is_reference
            } : nil,
            created_at: template.created_at,
            updated_at: template.updated_at
          }
        end

        def available_agricultural_tasks_for_crop(crop)
          if !crop.is_reference && crop.user_id.present?
            tasks = ::AgriculturalTask.user_owned.where(user_id: crop.user_id)
            tasks = tasks.where(region: crop.region) if crop.region.present?
            return tasks.order(:name)
          end

          if crop.is_reference
            tasks = ::AgriculturalTask.reference
            tasks = tasks.where(region: crop.region) if crop.region.present?
            return tasks.order(:name)
          end

          ::AgriculturalTask.none
        end

        def index_scope_for_user(user)
          if user.admin?
            ::Crop.where("is_reference = ? OR user_id = ?", true, user.id)
          else
            ::Crop.where(user_id: user.id, is_reference: false)
          end
        end

        def user_owned_non_reference_scope(user)
          ::Crop.where(user_id: user.id, is_reference: false)
        end

        def find_crop_model!(id)
          ::Crop.find(id)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def crop_stage_entity_from_record(record)
          temperature_req = record.temperature_requirement ? temperature_requirement_entity_from_record(record.temperature_requirement) : nil
          thermal_req = record.thermal_requirement ? thermal_requirement_entity_from_record(record.thermal_requirement) : nil
          sunshine_req = record.sunshine_requirement ? sunshine_requirement_entity_from_record(record.sunshine_requirement) : nil
          nutrient_req = record.nutrient_requirement ? nutrient_requirement_entity_from_record(record.nutrient_requirement) : nil

          Domain::Crop::Entities::CropStageEntity.new(
            id: record.id,
            crop_id: record.crop_id,
            name: record.name,
            order: record.order,
            temperature_requirement: temperature_req,
            thermal_requirement: thermal_req,
            sunshine_requirement: sunshine_req,
            nutrient_requirement: nutrient_req,
            created_at: record.created_at,
            updated_at: record.updated_at
          )
        end

        def temperature_requirement_entity_from_record(record)
          Domain::Crop::Entities::TemperatureRequirementEntity.new(
            id: record.id,
            crop_stage_id: record.crop_stage_id,
            base_temperature: record.base_temperature,
            optimal_min: record.optimal_min,
            optimal_max: record.optimal_max,
            low_stress_threshold: record.low_stress_threshold,
            high_stress_threshold: record.high_stress_threshold,
            frost_threshold: record.frost_threshold,
            sterility_risk_threshold: record.sterility_risk_threshold,
            max_temperature: record.max_temperature
          )
        end

        def thermal_requirement_entity_from_record(record)
          Domain::Crop::Entities::ThermalRequirementEntity.new(
            id: record.id,
            crop_stage_id: record.crop_stage_id,
            required_gdd: record.required_gdd
          )
        end

        def sunshine_requirement_entity_from_record(record)
          Domain::Crop::Entities::SunshineRequirementEntity.new(
            id: record.id,
            crop_stage_id: record.crop_stage_id,
            minimum_sunshine_hours: record.minimum_sunshine_hours,
            target_sunshine_hours: record.target_sunshine_hours
          )
        end

        def nutrient_requirement_entity_from_record(record)
          Domain::Crop::Entities::NutrientRequirementEntity.new(
            id: record.id,
            crop_stage_id: record.crop_stage_id,
            daily_uptake_n: record.daily_uptake_n,
            daily_uptake_p: record.daily_uptake_p,
            daily_uptake_k: record.daily_uptake_k,
            region: record.region
          )
        end

        def attributes_from_crop_stage_dto(dto)
          {
            name: dto[:name],
            order: dto[:order]
          }.compact
        end

        def attributes_from_temperature_requirement_dto(dto)
          {
            base_temperature: dto[:base_temperature],
            optimal_min: dto[:optimal_min],
            optimal_max: dto[:optimal_max],
            low_stress_threshold: dto[:low_stress_threshold],
            high_stress_threshold: dto[:high_stress_threshold],
            frost_threshold: dto[:frost_threshold],
            sterility_risk_threshold: dto[:sterility_risk_threshold],
            max_temperature: dto[:max_temperature]
          }.compact
        end

        def attributes_from_thermal_requirement_dto(dto)
          {
            required_gdd: dto[:required_gdd]
          }.compact
        end

        def attributes_from_sunshine_requirement_dto(dto)
          {
            minimum_sunshine_hours: dto[:minimum_sunshine_hours],
            target_sunshine_hours: dto[:target_sunshine_hours]
          }.compact
        end

        def attributes_from_nutrient_requirement_dto(dto)
          {
            daily_uptake_n: dto[:daily_uptake_n],
            daily_uptake_p: dto[:daily_uptake_p],
            daily_uptake_k: dto[:daily_uptake_k],
            region: dto[:region]
          }.compact
        end

        def authorized_crop_record_with_association_preloads!(user, id, for_edit:)
          crop = ::Crop.includes(CROP_ASSOCIATION_PRELOAD_INCLUDES).find(id)
          allowed = for_edit ? Domain::Shared::Policies::CropPolicy.edit_allowed?(user, is_reference: crop.is_reference, user_id: crop.user_id) : Domain::Shared::Policies::CropPolicy.view_allowed?(user, is_reference: crop.is_reference, user_id: crop.user_id)
          raise Domain::Shared::Policies::PolicyPermissionDenied unless allowed

          crop
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def reorder_crop_task_schedule_blueprint_priorities!(crop)
          blueprints = crop.crop_task_schedule_blueprints
                            .order(:gdd_trigger, :priority, :id)
          blueprints.each_with_index do |bp, index|
            bp.update_column(:priority, index + 1) if bp.priority != index + 1
          end
        end

      end
    end
  end
end
