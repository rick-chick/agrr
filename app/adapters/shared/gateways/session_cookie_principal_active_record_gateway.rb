# frozen_string_literal: true

module Adapters
  module Shared
    module Gateways
      class SessionCookiePrincipalActiveRecordGateway
        include Domain::Shared::Gateways::SessionCookiePrincipalGateway

        # @param session_id [String, nil]
        # @return [Domain::Shared::Dtos::SessionPrincipal]
        def principal_for_session_cookie(session_id)
          user = SessionCookieUserResolution.resolve_ar_user(session_id)
          SessionPrincipalMapper.from_user(user)
        end
      end
    end
  end
end
