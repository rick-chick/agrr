# frozen_string_literal: true

module Adapters
  module Shared
    module Gateways
      class ApiKeyPrincipalActiveRecordGateway
        include Domain::Shared::Gateways::ApiKeyPrincipalGateway

        # @param api_key [String]
        # @return [Domain::Shared::Dtos::SessionPrincipal, nil]
        def principal_for_api_key(api_key)
          user = ::User.find_by_api_key(api_key)
          return nil if user.nil?

          SessionPrincipalMapper.from_user(user)
        end
      end
    end
  end
end
