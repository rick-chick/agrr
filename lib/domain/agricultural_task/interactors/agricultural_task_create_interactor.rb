# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Interactors
      class AgriculturalTaskCreateInteractor < Domain::AgriculturalTask::Ports::AgriculturalTaskCreateInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call(create_input_dto)
          user = User.find(@user_id)
          task_model = Domain::Shared::Policies::AgriculturalTaskPolicy.build_for_create(::AgriculturalTask, user, {
            name: create_input_dto.name,
            description: create_input_dto.description,
            time_per_sqm: create_input_dto.time_per_sqm,
            weather_dependency: create_input_dto.weather_dependency,
            required_tools: create_input_dto.required_tools,
            skill_level: create_input_dto.skill_level,
            region: create_input_dto.region,
            task_type: create_input_dto.task_type
          })
          raise StandardError, task_model.errors.full_messages.join(', ') unless task_model.save

          task_entity = Domain::AgriculturalTask::Entities::AgriculturalTaskEntity.from_model(task_model)
          @output_port.on_success(task_entity)
        rescue ActiveRecord::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
