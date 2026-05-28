# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Interactors
      class AgriculturalTaskUpdateInteractor < Domain::AgriculturalTask::Ports::AgriculturalTaskUpdateInputPort
        def initialize(output_port:, user_id:, gateway:, crop_gateway:, crop_task_template_gateway:, translator:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @crop_gateway = crop_gateway
          @crop_task_template_gateway = crop_task_template_gateway
          @user_id = user_id
          @translator = translator
          @user_lookup = user_lookup
        end

        def call(update_input_dto)
          user = @user_lookup.find(@user_id)
          access_filter = Domain::Shared::Policies::AgriculturalTaskPolicy.record_access_filter(user)
          current = @gateway.find_by_id(update_input_dto.id)
          Domain::Shared::ReferenceRecordAuthorization.assert_edit_allowed!(access_filter, current)

          unless update_input_dto.is_reference.nil?
            requested = Domain::Shared::TypeConverters::BooleanConverter.cast(update_input_dto.is_reference)
            requested = false if requested.nil?
            unless Domain::Shared::Policies::ReferencableResourcePolicy.reference_flag_change_allowed?(user, requested: requested, current: current.reference?)
              @output_port.on_failure(
                Domain::Shared::Dtos::ReferenceFlagChangeDeniedFailure.new(
                  message: @translator.t("agricultural_tasks.flash.reference_flag_admin_only"),
                  resource_id: update_input_dto.id
                )
              )
              return false
            end
          end

          attrs = {}
          attrs[:name] = update_input_dto.name if Domain::Shared.present?(update_input_dto.name)
          attrs[:description] = update_input_dto.description if !update_input_dto.description.nil?
          attrs[:time_per_sqm] = update_input_dto.time_per_sqm if !update_input_dto.time_per_sqm.nil?
          attrs[:weather_dependency] = update_input_dto.weather_dependency if !update_input_dto.weather_dependency.nil?
          attrs[:required_tools] = update_input_dto.required_tools if !update_input_dto.required_tools.nil?
          attrs[:skill_level] = update_input_dto.skill_level if !update_input_dto.skill_level.nil?
          attrs[:region] = update_input_dto.region if !update_input_dto.region.nil?
          attrs[:task_type] = update_input_dto.task_type if !update_input_dto.task_type.nil?
          if !update_input_dto.is_reference.nil?
            attrs[:is_reference] = Domain::Shared::TypeConverters::BooleanConverter.cast(update_input_dto.is_reference)
            attrs[:is_reference] = false if attrs[:is_reference].nil?
          end

          sync_ids = update_input_dto.selected_crop_ids
          normalized = Domain::Shared::Policies::AgriculturalTaskPolicy.normalize_attrs_for_update(
            user,
            { is_reference: current.reference? },
            attrs
          )
          effective_reference = normalized.fetch(:is_reference, current.reference?)
          effective_user_id = normalized.fetch(:user_id, current.user_id)
          unless Domain::Shared::Policies::ReferencableResourcePolicy.reference_record_user_id_valid?(
            is_reference: effective_reference,
            user_id: effective_user_id
          )
            raise Domain::Shared::Exceptions::RecordInvalid.new(
              @translator.t("activerecord.errors.models.agricultural_task.attributes.user.blank")
            )
          end
          if normalized[:name]
            existing = find_existing_by_name(effective_reference, effective_user_id, normalized[:name])
            if Domain::Shared::Policies::ReferencableResourcePolicy.duplicate_name_record?(
              existing: existing,
              exclude_id: update_input_dto.id
            )
              raise Domain::Shared::Exceptions::RecordInvalid.new(
                @translator.t("activerecord.errors.models.agricultural_task.attributes.name.taken")
              )
            end
          end
          task_entity = nil
          @gateway.within_transaction do
            task_entity = @gateway.update(update_input_dto.id, normalized)
            sync_crop_task_templates!(task_entity, sync_ids, user) unless sync_ids.nil?
          end

          @output_port.on_success(task_entity)
          true
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
          false
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
          false
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
          false
        end

        private

        def find_existing_by_name(is_reference, user_id, name)
          if is_reference
            @gateway.find_by_reference_and_name(name: name)
          else
            @gateway.find_by_user_id_and_name(user_id: user_id, name: name)
          end
        end

        def sync_crop_task_templates!(task_entity, selected_crop_ids, user)
          policy = Domain::AgriculturalTask::Policies::CropTaskTemplateSyncPolicy
          region_filter = policy.crop_associate_region_filter(region: task_entity.region)
          scope_crop_ids = associate_scope_crop_ids(task_entity, region_filter, user)
          scope_crop_id_set = scope_crop_ids.to_set
          allowed_crop_ids = policy.allowed_crop_ids(
            scope_crop_ids: scope_crop_ids,
            selected_crop_ids: selected_crop_ids
          )
          current_template_crop_ids =
            @crop_task_template_gateway.list_by_agricultural_task_id(agricultural_task_id: task_entity.id).map(&:crop_id)
          crops_to_add = policy.crops_to_add(
            allowed_crop_ids: allowed_crop_ids,
            current_template_crop_ids: current_template_crop_ids
          )
          crops_to_remove = policy.crops_to_remove(
            allowed_crop_ids: allowed_crop_ids,
            current_template_crop_ids: current_template_crop_ids
          )
          template_attrs = policy.template_attributes_from_task_entity(task_entity)

          crops_to_add.each do |crop_id|
            crop_found = scope_crop_id_set.include?(crop_id)
            template_exists = template_link_exists?(task_entity.id, crop_id)
            next if policy.skip_template_create?(crop_found: crop_found, template_exists: template_exists)

            @crop_task_template_gateway.create(
              agricultural_task_id: task_entity.id,
              crop_id: crop_id,
              attrs: template_attrs
            )
          end
          crops_to_remove.each do |crop_id|
            crop_found = crop_record_exists?(crop_id)
            template_exists = template_link_exists?(task_entity.id, crop_id)
            next if policy.skip_template_remove?(crop_found: crop_found, template_exists: template_exists)

            @crop_task_template_gateway.delete(
              agricultural_task_id: task_entity.id,
              crop_id: crop_id
            )
          end
        end

        def associate_scope_crop_ids(task_entity, region_filter, user)
          if task_entity.reference?
            @crop_gateway.list_by_is_reference(is_reference: true, region: region_filter).map(&:id)
          else
            @crop_gateway.list_by_user_id(user_id: task_entity.user_id, region: region_filter)
              .select do |crop|
                Domain::Shared::Policies::CropPolicy.edit_allowed?(
                  user,
                  is_reference: Domain::Shared::ReferenceRecordAuthorization.referencable_is_reference(crop),
                  user_id: crop.user_id
                )
              end
              .map(&:id)
          end
        end

        def crop_record_exists?(crop_id)
          @crop_gateway.find_by_id(crop_id)
          true
        rescue Domain::Shared::Exceptions::RecordNotFound
          false
        end

        def template_link_exists?(agricultural_task_id, crop_id)
          !@crop_task_template_gateway.find_by_agricultural_task_id_and_crop_id(
            agricultural_task_id: agricultural_task_id,
            crop_id: crop_id
          ).nil?
        end
      end
    end
  end
end
