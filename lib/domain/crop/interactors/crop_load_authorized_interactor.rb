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
        # @return [Domain::Crop::Dtos::AuthorizedCropLoadedDto, nil]
        def call(crop_id, for_edit:)
          user = @user_lookup.find(@user_id)
          access_filter = Domain::Shared::Policies::CropPolicy.record_access_filter(user)
          @gateway.find_authorized_crop_loaded_bundle!(user, crop_id.to_i, for_edit: for_edit, access_filter: access_filter)
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
