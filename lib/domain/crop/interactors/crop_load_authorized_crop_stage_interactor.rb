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
          access_filter = Domain::Shared::Policies::CropPolicy.record_access_filter(user)
          @gateway.find_authorized_crop_with_crop_stage_bundle!(
            user,
            crop_id.to_i,
            crop_stage_id.to_i,
            for_edit: @for_edit,
            access_filter: access_filter
          )
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          @failure_presenter.on_not_found
          nil
        rescue Domain::Shared::Exceptions::RecordNotFound
          @failure_presenter.on_not_found
          nil
        end
      end
    end
  end
end
