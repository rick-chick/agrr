# frozen_string_literal: true

module Domain
  module Farm
    module Interactors
      class FarmDestroyInteractor < Domain::Farm::Ports::FarmDestroyInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call(farm_id)
          user = User.find(@user_id)
          farm_model = Domain::Shared::Policies::FarmPolicy.find_editable!(::Farm, user, farm_id)

          # 農場に紐づく栽培計画がある場合は削除不可
          if farm_model.free_crop_plans.any?
            raise StandardError, I18n.t('farms.flash.cannot_delete', count: farm_model.free_crop_plans.count)
          end

          undo_response = DeletionUndo::Manager.schedule(
            record: farm_model,
            actor: user,
            toast_message: I18n.t('farms.undo.toast', name: farm_model.display_name)
          )
          destroy_output_dto = Domain::Farm::Dtos::FarmDestroyOutputDto.new(undo: undo_response)
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