# frozen_string_literal: true

module Api
  module V1
    class ApiKeysController < BaseController
      before_action :authenticate_user!

      # POST /api/v1/api_keys/generate
      def generate
        if current_user.generate_api_key!
          render json: { api_key: current_user.api_key, success: true }
        else
          render json: { error: 'Failed to generate API key' }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/api_keys/regenerate
      def regenerate
        if current_user.regenerate_api_key!
          render json: { api_key: current_user.api_key, success: true }
        else
          render json: { error: 'Failed to regenerate API key' }, status: :unprocessable_entity
        end
      end
    end
  end
end
