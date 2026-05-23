# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Interactors
      class AgriculturalTaskCreateInteractor < Domain::AgriculturalTask::Ports::AgriculturalTaskCreateInputPort
        def initialize(output_port:, user_id:, gateway:, translator:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @translator = translator
          @user_lookup = user_lookup
        end

        def call(create_input_dto)
          attrs = nil
          user = @user_lookup.find(@user_id)
          is_reference = Domain::Shared::TypeConverters::BooleanConverter.cast(create_input_dto.is_reference) || false
          unless Domain::Shared::Policies::ReferencableResourcePolicy.reference_assignment_allowed?(user, is_reference: is_reference)
            raise Domain::Shared::Exceptions::RecordInvalid.new(@translator.t("agricultural_tasks.flash.reference_only_admin"))
          end

          attrs = Domain::Shared::Policies::AgriculturalTaskPolicy.normalize_attrs_for_create(user, {
            name: create_input_dto.name,
            description: create_input_dto.description,
            time_per_sqm: create_input_dto.time_per_sqm,
            weather_dependency: create_input_dto.weather_dependency,
            required_tools: create_input_dto.required_tools,
            skill_level: create_input_dto.skill_level,
            region: create_input_dto.region,
            task_type: create_input_dto.task_type,
            is_reference: is_reference
          })
          task_entity = @gateway.create_for_user(user, attrs)

          @output_port.on_success(task_entity)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          if attrs
            task = @gateway.build_after_create_failure_agricultural_task_for_master_form!(user: user, attributes: attrs)
            @output_port.on_failure(Domain::AgriculturalTask::Dtos::AgriculturalTaskHtmlCreateFailure.new(message: e.message, task_for_form: task))
          else
            @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
          end
        end
      end
    end
  end
end
