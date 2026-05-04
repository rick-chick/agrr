# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      # API マスター親作物（参照/所有に応じた view/edit 認可）に属する CropStage を取得。
      class CropLoadAuthorizedCropStageInteractor
        def initialize(failure_presenter:, user_id:, gateway:, user_lookup:, for_edit:)
          @failure_presenter = failure_presenter
          @user_id = user_id
          @gateway = gateway
          @user_lookup = user_lookup
          @for_edit = for_edit
        end

        # @return [Domain::Crop::Dtos::AuthorizedCropStageInCropContextDto, nil]
        def call(crop_id, crop_stage_id)
          user = @user_lookup.find(@user_id)
          @gateway.find_authorized_crop_stage_in_crop!(user, crop_id.to_i, crop_stage_id.to_i, for_edit: @for_edit)
        rescue Domain::Shared::Exceptions::RecordNotFound
          @failure_presenter.on_not_found
          nil
        end
      end
    end
  end
end
