# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      # HTML / API で共通。「認可済み作物」を一度の Gateway 読み込みで束ねて返す。
      # PolicyPermissionDenied / RecordNotFound 以外は再送出し（未定義レスポンスの隠蔽禁止）。
      class CropLoadAuthorizedInteractor
        def initialize(failure_presenter:, user_id:, gateway:, user_lookup:)
          @failure_presenter = failure_presenter
          @user_id = user_id
          @gateway = gateway
          @user_lookup = user_lookup
        end

        # @param crop_id [Integer, String]
        # @param for_edit [Boolean] true なら編集権限で評価
        # @return [Domain::Crop::Dtos::AuthorizedCropLoaded, nil]
        def call(input)
          user = @user_lookup.find(@user_id)
          access_filter = Domain::Shared::Policies::CropPolicy.record_access_filter(user)
          bundle = @gateway.find_crop_loaded_bundle!(input.crop_id.to_i, for_edit: input.for_edit)
          if input.for_edit
            Domain::Shared::ReferenceRecordAuthorization.assert_edit_allowed!(access_filter, bundle.crop_entity)
          else
            Domain::Shared::ReferenceRecordAuthorization.assert_view_allowed!(access_filter, bundle.crop_entity)
          end
          bundle
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          @failure_presenter.on_permission_denied
          nil
        rescue Domain::Shared::Exceptions::RecordNotFound
          @failure_presenter.on_not_found
          nil
        end
      end
    end
  end
end
