# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Interactors
      class AgriculturalTaskUpdateInteractor < Domain::AgriculturalTask::Ports::AgriculturalTaskUpdateInputPort
        def initialize(output_port:, user_id:, gateway:, translator:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
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
          task_entity = @gateway.update_for_user(
            user,
            update_input_dto.id,
            normalized,
            selected_crop_ids: sync_ids
          )

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
      end
    end
  end
end
