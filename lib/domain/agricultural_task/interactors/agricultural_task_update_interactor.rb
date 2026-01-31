# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Interactors
      class AgriculturalTaskUpdateInteractor < Domain::AgriculturalTask::Ports::AgriculturalTaskUpdateInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call(update_input_dto)
          user = User.find(@user_id)
          attrs = {}
          attrs[:name] = update_input_dto.name if update_input_dto.name.present?
          attrs[:description] = update_input_dto.description if !update_input_dto.description.nil?
          attrs[:time_per_sqm] = update_input_dto.time_per_sqm if !update_input_dto.time_per_sqm.nil?
          attrs[:weather_dependency] = update_input_dto.weather_dependency if !update_input_dto.weather_dependency.nil?
          attrs[:required_tools] = update_input_dto.required_tools if !update_input_dto.required_tools.nil?
          attrs[:skill_level] = update_input_dto.skill_level if !update_input_dto.skill_level.nil?
          attrs[:region] = update_input_dto.region if !update_input_dto.region.nil?
          attrs[:task_type] = update_input_dto.task_type if !update_input_dto.task_type.nil?
          if !update_input_dto.is_reference.nil?
            attrs[:is_reference] = ActiveModel::Type::Boolean.new.cast(update_input_dto.is_reference)
            attrs[:is_reference] = false if attrs[:is_reference].nil?
          end

          task_model = Domain::Shared::Policies::AgriculturalTaskPolicy.find_editable!(::AgriculturalTask, user, update_input_dto.id)
          Domain::Shared::Policies::AgriculturalTaskPolicy.apply_update!(user, task_model, attrs)
          raise StandardError, task_model.errors.full_messages.join(', ') if task_model.errors.any?

          task_entity = Domain::AgriculturalTask::Entities::AgriculturalTaskEntity.from_model(task_model.reload)
          @output_port.on_success(task_entity)
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          raise
        rescue ActiveRecord::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
