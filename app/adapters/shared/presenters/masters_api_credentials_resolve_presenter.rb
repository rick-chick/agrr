# frozen_string_literal: true

module Adapters
  module Shared
    module Presenters
      class MastersApiCredentialsResolvePresenter
        def initialize(view:)
          @view = view
        end

        def on_success(principal:)
          @view.assign_authenticated_principal(principal)
        end

        def on_invalid_api_key
          @view.render_response(json: { error: "Invalid API key" }, status: :unauthorized)
          @view.halt_masters_api_authentication!
        end

        def on_login_required
          @view.render_response(
            json: { error: I18n.t("auth.api.login_required") },
            status: :unauthorized
          )
          @view.halt_masters_api_authentication!
        end
      end
    end
  end
end
