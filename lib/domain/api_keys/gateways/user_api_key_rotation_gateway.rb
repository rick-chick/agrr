# frozen_string_literal: true

module Domain
  module ApiKeys
    module Gateways
      class UserApiKeyRotationGateway
        # @return [Hash] keys: :ok (Boolean), :api_key (String, nil), :error (nil | :not_found)
        def rotate(user_id:, regenerate:)
          raise NotImplementedError, "Subclasses must implement rotate"
        end
      end
    end
  end
end
