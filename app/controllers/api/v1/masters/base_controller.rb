# frozen_string_literal: true

module Api
  module V1
    module Masters
      class BaseController < ApplicationController
        # API versioning base controller for master data management
        # Skip CSRF verification for API endpoints (use API key auth instead)
        skip_before_action :verify_authenticity_token
        
        # ApplicationControllerの認証をスキップし、APIキー認証を使用
        skip_before_action :authenticate_user!
        before_action :authenticate_api_key!

        private

        def authenticate_api_key!
          api_key = extract_api_key
          
          unless api_key
            render json: { error: 'API key is required' }, status: :unauthorized
            return false
          end

          user = User.find_by_api_key(api_key)
          
          unless user
            render json: { error: 'Invalid API key' }, status: :unauthorized
            return false
          end

          @current_user = user
          true
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
