# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Interactors
      class AgriculturalTaskDestroyInteractor < Domain::AgriculturalTask::Ports::AgriculturalTaskDestroyInputPort
        def initialize(output_port:, user_id:, gateway:, logger:, translator:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
          @translator = translator
          @user_lookup = user_lookup
        end

        def call(task_id)
          user = @user_lookup.find(@user_id)
          result = @gateway.soft_destroy_with_undo(
            user: user,
            task_id: task_id,
            auto_hide_after: 5000,
            translator: @translator
          )
          if result[:success]
            destroy_output_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskDestroyOutputDto.new(undo: result[:undo_entity])
            @output_port.on_success(destroy_output_dto)
          else
            @output_port.on_failure(result[:error_dto])
          end
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          raise
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
