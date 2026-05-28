# frozen_string_literal: true

module Domain
  module Shared
    module Gateways
      # API キー文字列から {SessionPrincipal} を返す（永続はアダプタのみ）。
      module ApiKeyPrincipalGateway
        # @param api_key [String]
        # @return [Domain::Shared::Dtos::SessionPrincipal, nil]
        def principal_for_api_key(api_key)
          raise NotImplementedError, "#{self.class}#principal_for_api_key"
        end
      end
    end
  end
end
