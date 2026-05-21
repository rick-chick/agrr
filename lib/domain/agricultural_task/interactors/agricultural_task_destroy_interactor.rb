# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Interactors
      class AgriculturalTaskDestroyInteractor < Domain::AgriculturalTask::Ports::AgriculturalTaskDestroyInputPort
        def initialize(output_port:, user_id:, gateway:, translator:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @translator = translator
          @user_lookup = user_lookup
        end

        def call(task_id)
          user = @user_lookup.find(@user_id)
          access_filter = Domain::Shared::Policies::AgriculturalTaskPolicy.record_access_filter(user)
          result = @gateway.soft_delete_with_undo(
            user: user,
            task_id: task_id,
            auto_hide_after: 5000,
            translator: @translator,
            access_filter: access_filter
          )
          if result[:success]
            destroy_output_dto = Domain::AgriculturalTask::Dtos::AgriculturalTaskDestroyOutput.new(undo: result[:undo_entity])
            @output_port.on_success(destroy_output_dto)
          else
            @output_port.on_failure(result[:error_dto])
          end
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(@translator.t("agricultural_tasks.flash.not_found")))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end
      end
    end
  end
end
