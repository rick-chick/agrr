# frozen_string_literal: true

module Presenters
  module Api
    module V1
      module Auth
        class AuthUserLogoutApiPresenter
          include Domain::Auth::Ports::AuthUserLogoutOutputPort

          def initialize(view:)
            @view = view
          end

          def on_success
            @view.clear_session_cookie
            @view.render json: { success: true }
          end

          def on_not_logged_in
            @view.clear_session_cookie
            @view.render json: { success: false, error: I18n.t("auth.api.login_required") }, status: :unauthorized
          end
        end
      end
    end
  end
end
