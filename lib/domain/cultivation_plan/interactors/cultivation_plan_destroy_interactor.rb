# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class CultivationPlanDestroyInteractor < Domain::CultivationPlan::Ports::CultivationPlanDestroyInputPort
        def initialize(output_port:, user_id:, gateway:, translator:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @translator = translator
          @user_lookup = user_lookup
        end

        def call(plan_id)
          user = @user_lookup.find(@user_id)
          display_name = @gateway.private_owned_plan_display_name(user: user, plan_id: plan_id)
          toast_message = @translator.t("plans.undo.toast", name: display_name)
          undo_response = @gateway.delete(plan_id, user, toast_message: toast_message)
          destroy_output_dto = Domain::CultivationPlan::Dtos::CultivationPlanDestroyOutput.new(undo: undo_response)
          @output_port.on_success(destroy_output_dto)
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          handle_failure(@translator.t("plans.errors.not_found"))
        rescue Domain::Shared::Exceptions::RecordNotFound
          handle_failure(@translator.t("plans.errors.not_found"))
        rescue Domain::Shared::Exceptions::AssociationInUse
          handle_failure(@translator.t("plans.errors.delete_failed"))
        rescue Domain::DeletionUndo::Exceptions::DeletionUndoError => e
          handle_failure(@translator.t("plans.errors.delete_error", message: e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          handle_failure(e.message)
        end

        private

        def handle_failure(message)
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(message))
        end
      end
    end
  end
end
