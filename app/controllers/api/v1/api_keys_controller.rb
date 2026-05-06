# frozen_string_literal: true

module Api
  module V1
    class ApiKeysController < BaseController
      before_action :authenticate_user!

      # POST /api/v1/api_keys/generate
      def generate
        presenter = Presenters::Api::ApiKeys::ApiUserApiKeyRotatePresenter.new(view: self)
        Domain::ApiKeys::Interactors::ApiUserApiKeyRotateInteractor.new(
          output_port: presenter,
          gateway: CompositionRoot.user_api_key_rotation_gateway
        ).call(user_id: current_user.id, regenerate: false)
      end

      # POST /api/v1/api_keys/regenerate
      def regenerate
        presenter = Presenters::Api::ApiKeys::ApiUserApiKeyRotatePresenter.new(view: self)
        Domain::ApiKeys::Interactors::ApiUserApiKeyRotateInteractor.new(
          output_port: presenter,
          gateway: CompositionRoot.user_api_key_rotation_gateway
        ).call(user_id: current_user.id, regenerate: true)
      end
    end
  end
end
