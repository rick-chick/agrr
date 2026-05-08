# frozen_string_literal: true

module Domain
  module ApiKeys
    module Interactors
      class UserApiKeyRotateInteractor
        def initialize(output_port:, gateway:)
          @output_port = output_port
          @gateway = gateway
        end

        def call(user_id:, regenerate:)
          result = @gateway.rotate(user_id: user_id, regenerate: regenerate)
          if result[:error] == :not_found
            @output_port.on_failure(message: "User not found")
            return
          end

          if result[:ok]
            @output_port.on_success(api_key: result[:api_key])
          else
            msg = regenerate ? "Failed to regenerate API key" : "Failed to generate API key"
            @output_port.on_failure(message: msg)
          end
        end
      end
    end
  end
end
