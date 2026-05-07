# frozen_string_literal: true

module Adapters
  module Api
    module V1
      module Masters
        # マスター API の API キー／セッション Cookie から User を解決する（ActiveRecord はこの境界内のみ）。
        class MastersApiSessionResolveGateway
          def initialize(session_cookie_resolver: Adapters::Shared::Gateways::SessionCookieUserActiveRecordGateway.new)
            @session_cookie_resolver = session_cookie_resolver
          end

          def user_for_api_key(api_key)
            return nil if api_key.blank?

            User.find_by_api_key(api_key)
          end

          def user_for_session_cookie(session_id)
            @session_cookie_resolver.user_for_session_cookie(session_id)
          end
        end
      end
    end
  end
end
