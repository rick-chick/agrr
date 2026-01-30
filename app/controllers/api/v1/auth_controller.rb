# frozen_string_literal: true

module Api
  module V1
    class AuthController < BaseController
      def me
        render json: { user: serialized_user(current_user) }
      end

      def logout
        current_user.sessions.destroy_all
        clear_session_cookie
        render json: { success: true }
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

        begin
          cookie_domain = request.cookie_domain.presence
        rescue NoMethodError
          cookie_domain = nil
        end

        cookies.delete(:session_id, path: '/')
        cookies.delete(:session_id, domain: cookie_domain, path: '/') if cookie_domain
        cookies.delete(:session_id, domain: :all, path: '/')
      end
    end
  end
end
