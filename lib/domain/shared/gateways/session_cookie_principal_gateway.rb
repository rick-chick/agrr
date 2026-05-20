# frozen_string_literal: true

module Domain
  module Shared
    module Gateways
      # ブラウザ session_id Cookie から {SessionPrincipal} を返す（永続はアダプタのみ）。
      module SessionCookiePrincipalGateway
        # @param session_id [String, nil]
        # @return [Domain::Shared::Dtos::SessionPrincipal]
        def principal_for_session_cookie(session_id)
          raise NotImplementedError, "#{self.class}#principal_for_session_cookie"
        end
      end
    end
  end
end
