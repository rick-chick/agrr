# frozen_string_literal: true

module Adapters
  module ApiKeys
    module Presenters
      class ApiUserApiKeyRotateApiPresenter
        def initialize(view:)
          @view = view
        end

        def on_success(api_key:)
          @view.render json: { api_key: api_key, success: true }
        end

        def on_failure(message:)
          @view.render json: { error: message }, status: :unprocessable_entity
        end
      end
    end
  end
end
