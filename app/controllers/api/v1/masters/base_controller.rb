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

        def assign_authenticated_principal(principal)
          @current_user = principal
        end

        def halt_masters_api_authentication!
          @masters_api_auth_halted = true
        end

        def render_response(json:, status:)
          render(json: json, status: status)
        end

        private

        def authenticate_api_key_or_session!
          @masters_api_auth_halted = false
          presenter = Adapters::Shared::Presenters::MastersApiCredentialsResolvePresenter.new(view: self)
          Domain::Shared::Interactors::MastersApiCredentialsResolveInteractor.new(
            output_port: presenter,
            api_key_principal_gateway: CompositionRoot.api_key_principal_gateway,
            session_cookie_principal_gateway: CompositionRoot.session_cookie_principal_gateway
          ).call(
            Domain::Shared::Dtos::MastersApiCredentialsResolveInput.new(
              api_key: extract_api_key,
              session_id: cookies[:session_id]
            )
          )
          return false if @masters_api_auth_halted

          true
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

        def translator
          @translator ||= CompositionRoot.translator
        end
      end
    end
  end
end
