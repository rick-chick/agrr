# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class CultivationPlanDestroyInteractor < Domain::CultivationPlan::Ports::CultivationPlanDestroyInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call(plan_id)
          user = User.find(@user_id)
          undo_response = @gateway.destroy(plan_id, user)
          destroy_output_dto = Domain::CultivationPlan::Dtos::CultivationPlanDestroyOutputDto.new(undo: undo_response)
          @output_port.on_success(destroy_output_dto)
        rescue PolicyPermissionDenied, ActiveRecord::RecordNotFound
          handle_failure(I18n.t('plans.errors.not_found'))
        rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError
          handle_failure(I18n.t('plans.errors.delete_failed'))
        rescue DeletionUndo::Error => e
          handle_failure(I18n.t('plans.errors.delete_error', message: e.message))
        rescue StandardError => e
          handle_failure(e.message.presence || I18n.t('plans.errors.delete_failed'))
        end

        private

        def handle_failure(message)
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(message))
        end
      end
    end
  end
end
