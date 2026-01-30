# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropDestroyInteractor < Domain::Crop::Ports::CropDestroyInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call(crop_id)
          user = User.find(@user_id)
          crop_model = Domain::Shared::Policies::CropPolicy.find_editable!(::Crop, user, crop_id)

          if crop_model.cultivation_plan_crops.any?
            @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(I18n.t('crops.flash.cannot_delete_in_use.plan')))
            return
          end
          if crop_model.free_crop_plans.any?
            @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(I18n.t('crops.flash.cannot_delete_in_use.other')))
            return
          end
          if crop_model.pesticides.any?
            @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(I18n.t('crops.flash.cannot_delete_in_use.other')))
            return
          end

          undo_response = DeletionUndo::Manager.schedule(
            record: crop_model,
            actor: user,
            toast_message: I18n.t('crops.undo.toast', name: crop_model.name)
          )
          destroy_output_dto = Domain::Crop::Dtos::CropDestroyOutputDto.new(undo: undo_response)
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
