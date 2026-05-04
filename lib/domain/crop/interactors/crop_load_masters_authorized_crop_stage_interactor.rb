# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      # マスター系: 自ユーザーの非参照作物に属する CropStage を取得。失敗時は failure_presenter。
      class CropLoadMastersAuthorizedCropStageInteractor
        def initialize(failure_presenter:, user_id:, gateway:, user_lookup:)
          @failure_presenter = failure_presenter
          @user_id = user_id
          @gateway = gateway
          @user_lookup = user_lookup
        end

        # @return [Domain::Crop::Dtos::AuthorizedCropStageInCropContextDto, nil]
        def call(crop_id, crop_stage_id)
          user = @user_lookup.find(@user_id)
          @gateway.find_masters_crop_with_crop_stage_bundle!(user, crop_id.to_i, crop_stage_id.to_i)
        rescue Domain::Shared::Exceptions::RecordNotFound
          @failure_presenter.on_not_found
          nil
        end
      end
    end
  end
end
