# frozen_string_literal: true

module Adapters
  module Api
    module V1
      module Masters
        # マスター API の API キー／セッション Cookie から User を解決する（ActiveRecord はこの境界内のみ）。
        class MastersApiSessionResolveGateway
          def user_for_api_key(api_key)
            return nil if api_key.blank?

            User.find_by_api_key(api_key)
          end

          def user_for_session_cookie(session_id)
            return User.anonymous_user unless session_id
            return User.anonymous_user unless Session.valid_session_id?(session_id)

            session = Session.active.find_by(session_id: session_id)
            return User.anonymous_user unless session

            session.extend_expiration if session.expires_at < 1.week.from_now
            session.user
          end
        end
      end
    end
  end
end
