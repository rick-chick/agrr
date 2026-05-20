# frozen_string_literal: true

module Domain
  module ApiKeys
    module Dtos
      # `UserApiKeyRotationGateway#rotate` の戻り。
      class UserApiKeyRotationOutput
        ERROR_NOT_FOUND = :not_found

        attr_reader :ok, :api_key, :error

        # @param ok [Boolean]
        # @param api_key [String, nil]
        # @param error [Symbol, nil] 例: {ERROR_NOT_FOUND}
        def initialize(ok:, api_key: nil, error: nil)
          @ok = ok
          @api_key = api_key
          @error = error
        end

        def not_found?
          error == ERROR_NOT_FOUND
        end
      end
    end
  end
end
