# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Interactors
      class AgriculturalTaskDestroyInteractor < Domain::AgriculturalTask::Ports::AgriculturalTaskDestroyInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call(task_id)
          user = User.find(@user_id)
          task_model = Domain::Shared::Policies::AgriculturalTaskPolicy.find_editable!(::AgriculturalTask, user, task_id)
          undo_response = DeletionUndo::Manager.schedule(
            record: task_model,
            actor: user,
            toast_message: I18n.t('agricultural_tasks.undo.toast', name: task_model.name)
          )
          destroy_output_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskDestroyOutputDto.new(undo: undo_response)
          @output_port.on_success(destroy_output_dto)
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
