# frozen_string_literal: true

module Api
  module V1
    class BaseController < ApplicationController
      # API versioning base controller
      # Skip CSRF verification for API endpoints (use token-based auth instead)
      skip_before_action :verify_authenticity_token
      before_action :authenticate_request, except: [:health_check]

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

      def authenticate_request
        # Add authentication logic here
        # For now, we'll skip authentication for demo purposes
        true
      end
    end
  end
end
