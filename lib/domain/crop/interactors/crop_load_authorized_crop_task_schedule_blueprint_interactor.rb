# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropLoadAuthorizedCropTaskScheduleBlueprintInteractor
        def initialize(failure_presenter:, user_id:, gateway:, user_lookup:)
          @failure_presenter = failure_presenter
          @user_id = user_id
          @gateway = gateway
          @user_lookup = user_lookup
        end

        # @return [Domain::Crop::Dtos::AuthorizedCropTaskScheduleBlueprintInCropContextDto, nil]
        def call(crop_id, blueprint_id)
          user = @user_lookup.find(@user_id)
          @gateway.find_authorized_crop_task_schedule_blueprint_in_crop!(user, crop_id.to_i, blueprint_id.to_i)
        rescue Domain::Shared::Exceptions::RecordNotFound
          @failure_presenter.on_not_found
          nil
        end
      end
    end
  end
end
