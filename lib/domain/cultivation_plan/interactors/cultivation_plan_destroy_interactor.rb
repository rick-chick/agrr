# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class CultivationPlanDestroyInteractor < Domain::CultivationPlan::Ports::CultivationPlanDestroyInputPort
        def initialize(output_port:, gateway:, user_id:, logger:, translator:, user_lookup: Domain::Shared::Ports::UserLookupPort.default)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
          @translator = translator
          @user_lookup = user_lookup
        end

        def call(plan_id)
          user = @user_lookup.find(@user_id)
          undo_response = @gateway.destroy(plan_id, user)
          destroy_output_dto = Domain::CultivationPlan::Dtos::CultivationPlanDestroyOutputDto.new(undo: undo_response)
          @output_port.on_success(destroy_output_dto)
        rescue ::PolicyPermissionDenied, Domain::Shared::Policies::PolicyPermissionDenied
          handle_failure(@translator.t("plans.errors.not_found"))
        rescue Domain::Shared::Exceptions::RecordNotFound
          handle_failure(@translator.t("plans.errors.not_found"))
        rescue Domain::Shared::Exceptions::AssociationInUse
          handle_failure(@translator.t("plans.errors.delete_failed"))
        rescue DeletionUndo::Error => e
          handle_failure(@translator.t("plans.errors.delete_error", message: e.message))
        rescue StandardError => e
          handle_failure(e.message.presence || @translator.t("plans.errors.delete_failed"))
        end

        private

        def handle_failure(message)
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(message))
        end
      end
    end
  end
end
