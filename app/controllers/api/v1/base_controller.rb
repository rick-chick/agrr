# frozen_string_literal: true

module Api
  module V1
    class BaseController < ApplicationController
      # API versioning base controller
      # Skip CSRF verification for API endpoints (use token-based auth instead)
      skip_before_action :verify_authenticity_token
      
      # ApplicationControllerの認証をスキップし、API専用の認証を使用
      skip_before_action :authenticate_user!
      before_action :authenticate_api_request, except: [:health_check]

      def health_check
        render json: {
          status: 'ok',
          database: 'sqlite3',
          storage: 'connected',
          timestamp: Time.current,
          environment: Rails.env,
          version: '1.0.0'
        }
      end

      private

      def authenticate_api_request
        # C案: エンドポイントごとに認証を分ける
        # CRUD操作は認証必須
        # current_userがアノニマスユーザーの場合は401を返す
        if current_user.anonymous?
          render json: { error: I18n.t('auth.api.login_required') }, status: :unauthorized
          return false
        end
        
        true
      end
    end
  end
end
