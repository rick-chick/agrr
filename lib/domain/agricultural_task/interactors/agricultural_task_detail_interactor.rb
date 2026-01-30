# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Interactors
      class AgriculturalTaskDetailInteractor < Domain::AgriculturalTask::Ports::AgriculturalTaskDetailInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call(task_id)
          user = User.find(@user_id)
          task_model = Domain::Shared::Policies::AgriculturalTaskPolicy.find_visible!(::AgriculturalTask, user, task_id)
          task_entity = Domain::AgriculturalTask::Entities::AgriculturalTaskEntity.from_model(task_model)
          task_detail_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskDetailOutputDto.new(task: task_entity)
          @output_port.on_success(task_detail_dto)
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
