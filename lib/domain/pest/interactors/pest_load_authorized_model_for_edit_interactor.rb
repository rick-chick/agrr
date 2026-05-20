# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      # HTML before_action / API ai_update で @pest を設定するために、認可済み読み込み結果（DTO）で取得する。
      # PolicyPermissionDenied / RecordNotFound 以外は再送出し（未定義レスポンスの隠蔽禁止）。
      class PestLoadAuthorizedModelForEditInteractor
        def initialize(failure_presenter:, user_id:, gateway:, user_lookup:)
          @failure_presenter = failure_presenter
          @gateway = gateway
          @user_id = user_id
          @user_lookup = user_lookup
        end

        # @param pest_id [Integer, String]
        # @return [Domain::Pest::Ports::PestAuthorizedLoad, nil]
        def call(pest_id)
          user = @user_lookup.find(@user_id)
          access_filter = Domain::Shared::Policies::PestPolicy.record_access_filter(user)
          @gateway.find_authorized_pest_loaded_bundle!(user, pest_id.to_i, for_edit: true, access_filter: access_filter)
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
