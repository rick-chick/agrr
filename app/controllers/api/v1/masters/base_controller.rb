# frozen_string_literal: true

module Api
  module V1
    module Masters
      class BaseController < ApplicationController
        # API versioning base controller for master data management
        # Skip CSRF verification for API endpoints (use API key auth instead)
        skip_before_action :verify_authenticity_token

        # ApplicationControllerの認証をスキップし、APIキーまたはセッション認証を使用
        # APIキー: プログラムからのアクセス用
        # セッション: SPAでWebログインしたユーザー用（ほ場管理画面など）
        skip_before_action :authenticate_user!

        before_action :authenticate_api_key_or_session!

        private

        def authenticate_api_key_or_session!
          gw = CompositionRoot.masters_api_session_resolve_gateway
          api_key = extract_api_key
          if api_key.present?
            user = gw.user_for_api_key(api_key)
            unless user
              render json: { error: "Invalid API key" }, status: :unauthorized
              return false
            end
            @current_user = user
            return true
          end

          session_user = gw.user_for_session_cookie(cookies[:session_id])
          if session_user && !session_user.anonymous?
            @current_user = session_user
            return true
          end

          render json: { error: I18n.t("auth.api.login_required") }, status: :unauthorized
          false
        end

        def extract_api_key
          # APIキーは以下の方法で取得可能:
          # 1. Authorizationヘッダー: "Bearer <api_key>"
          # 2. X-API-Keyヘッダー
          # 3. api_keyパラメータ（クエリパラメータ）

          # Authorizationヘッダーから取得
          auth_header = request.headers["Authorization"]
          if auth_header&.start_with?("Bearer ")
            return auth_header.sub(/^Bearer /, "").strip
          end

          # X-API-Keyヘッダーから取得
          return request.headers["X-API-Key"] if request.headers["X-API-Key"].present?

          # クエリパラメータから取得
          return params[:api_key] if params[:api_key].present?

          nil
        end

        def current_user
          @current_user
        end

        private

        def translator
          @translator ||= CompositionRoot.translator
        end
      end
    end
  end
end
