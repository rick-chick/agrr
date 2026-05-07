# frozen_string_literal: true

module Api
  module V1
    class AuthController < BaseController
      def me
        render json: { user: serialized_user(current_user) }
      end

      def logout
        presenter = Presenters::Api::V1::Auth::AuthUserLogoutApiPresenter.new(view: self)
        Domain::Auth::Interactors::AuthUserLogoutInteractor.new(
          output_port: presenter,
          session_revocation_gateway: CompositionRoot.user_session_revocation_gateway
        ).call(authenticated: logged_in?, user_id: current_user.id)
      end

      private

      def serialized_user(user)
        {
          id: user.id,
          name: user.name,
          email: user.email,
          avatar_url: user.avatar_url,
          admin: user.admin?,
          api_key: user.api_key
        }
      end

      def clear_session_cookie
        cookies.delete(:session_id)

        cookie_domain = if request.respond_to?(:cookie_domain, true)
          request.cookie_domain.presence
        end

        cookies.delete(:session_id, path: "/")
        cookies.delete(:session_id, domain: cookie_domain, path: "/") if cookie_domain
        cookies.delete(:session_id, domain: :all, path: "/")
      end

      public :clear_session_cookie
    end
  end
end
