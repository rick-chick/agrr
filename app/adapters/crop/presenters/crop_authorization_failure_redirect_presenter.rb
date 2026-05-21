# frozen_string_literal: true

module Adapters
  module Crop
    module Presenters
      # before_action で作物取得に失敗したとき、一覧へリダイレクトする。
      class CropAuthorizationFailureRedirectPresenter
        include Domain::Crop::Ports::CropLoadedAuthorizationFailurePort

        def initialize(view:, permission_message_key:)
          @view = view
          @permission_message_key = permission_message_key
        end

        def on_permission_denied
          @view.redirect_to @view.crops_path, alert: I18n.t(@permission_message_key)
        end

        def on_not_found
          @view.redirect_to @view.crops_path, alert: I18n.t("crops.flash.not_found")
        end
      end
    end
  end
end
