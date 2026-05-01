# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      # HTML before_action / API ai_update で @pest を設定するために、認可済み永続モデルを取得する。
      class PestLoadAuthorizedModelForEditInteractor
        def initialize(output_port:, user_id:, gateway:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @user_lookup = user_lookup
        end

        def call(pest_id)
          user = @user_lookup.find(@user_id)
          pest = @gateway.authorized_record_for_edit(user, pest_id)
          @output_port.on_success(pest)
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          @output_port.on_failure(:no_permission)
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_failure(:not_found)
        end
      end
    end
  end
end
