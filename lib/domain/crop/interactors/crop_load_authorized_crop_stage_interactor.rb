# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      # API マスター親作物（参照/所有に応じた view/edit 認可）に属する CropStage を取得。
      class CropLoadAuthorizedCropStageInteractor
        def initialize(failure_presenter:, user_id:, crop_gateway:, crop_stage_gateway:, user_lookup:, for_edit:)
          @failure_presenter = failure_presenter
          @user_id = user_id
          @crop_gateway = crop_gateway
          @crop_stage_gateway = crop_stage_gateway
          @user_lookup = user_lookup
          @for_edit = for_edit
        end

        # @return [Domain::Crop::Dtos::AuthorizedCropStageInCropContext, nil]
        def call(input)
          user = @user_lookup.find(@user_id)
          access_filter = Domain::Shared::Policies::CropPolicy.record_access_filter(user)
          crop_entity = @crop_gateway.find_by_id(input.crop_id.to_i)
          crop_stage_entity = @crop_stage_gateway.find_by_id(input.crop_stage_id.to_i)
          if crop_stage_entity.crop_id != crop_entity.id
            raise Domain::Shared::Exceptions::RecordNotFound, "CropStage not found"
          end

          if @for_edit
            Domain::Shared::ReferenceRecordAuthorization.assert_edit_allowed!(access_filter, crop_entity)
          else
            Domain::Shared::ReferenceRecordAuthorization.assert_view_allowed!(access_filter, crop_entity)
          end

          Domain::Crop::Dtos::AuthorizedCropStageInCropContext.new(
            crop_entity: crop_entity,
            crop_stage_entity: crop_stage_entity
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
