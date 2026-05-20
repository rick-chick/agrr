# frozen_string_literal:

module Adapters
  module Pest
    module Presenters
      module Html
        # before_action で害虫取得に失敗したとき、一覧へリダイレクトする。
        class PestAuthorizationFailureRedirectPresenter
          include Domain::Pest::Ports::PestLoadedAuthorizationFailurePort

          def initialize(view:, permission_message_key:)
            @view = view
            @permission_message_key = permission_message_key
          end

          def on_permission_denied
            @view.redirect_to @view.pests_path, alert: I18n.t(@permission_message_key)
          end

          def on_not_found
            @view.redirect_to @view.pests_path, alert: I18n.t("pests.flash.not_found")
          end
        end
      end
    end
  end
end
