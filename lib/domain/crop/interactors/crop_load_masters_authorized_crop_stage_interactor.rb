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

        # @return [Domain::Crop::Dtos::AuthorizedCropStageInCropContext, nil]
        def call(input)
          user = @user_lookup.find(@user_id)
          access_filter = Domain::Shared::Policies::CropPolicy.record_access_filter(user)
          bundle = @gateway.find_crop_with_crop_stage_bundle!(
            input.crop_id.to_i,
            input.crop_stage_id.to_i,
            for_edit: false
          )
          Domain::Shared::ReferenceRecordAuthorization.assert_edit_allowed!(access_filter, bundle.crop_entity)
          bundle
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
