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
          api_key = extract_api_key
          if api_key.present?
            user = User.find_by_api_key(api_key)
            unless user
              render json: { error: 'Invalid API key' }, status: :unauthorized
              return false
            end
            @current_user = user
            return true
          end

          # フォールバック: セッション認証（SPAのWebログインユーザー向け）
          session_user = resolve_session_user
          if session_user && !session_user.anonymous?
            @current_user = session_user
            return true
          end

          render json: { error: I18n.t('auth.api.login_required') }, status: :unauthorized
          false
        end

        def resolve_session_user
          session_id = cookies[:session_id]
          return User.anonymous_user unless session_id
          return User.anonymous_user unless Session.valid_session_id?(session_id)

          session = Session.active.find_by(session_id: session_id)
          return User.anonymous_user unless session

          session.extend_expiration if session.expires_at < 1.week.from_now
          session.user
        end

        def extract_api_key
          # APIキーは以下の方法で取得可能:
          # 1. Authorizationヘッダー: "Bearer <api_key>"
          # 2. X-API-Keyヘッダー
          # 3. api_keyパラメータ（クエリパラメータ）
          
          # Authorizationヘッダーから取得
          auth_header = request.headers['Authorization']
          if auth_header&.start_with?('Bearer ')
            return auth_header.sub(/^Bearer /, '').strip
          end
          
          # X-API-Keyヘッダーから取得
          return request.headers['X-API-Key'] if request.headers['X-API-Key'].present?
          
          # クエリパラメータから取得
          return params[:api_key] if params[:api_key].present?
          
          nil
        end

        def current_user
          @current_user
        end
      end
    end
  end
end
