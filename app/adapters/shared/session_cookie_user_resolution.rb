# frozen_string_literal: true

module Adapters
  module Shared
    # session_id Cookie から ActiveRecord `User` を解決する（adapter 境界内のみ）。
    module SessionCookieUserResolution
      module_function

      # @param session_id [String, nil]
      # @return [User]
      def resolve_ar_user(session_id)
        return ::User.anonymous_user unless session_id
        return ::User.anonymous_user unless ::Session.valid_session_id?(session_id)

        session = ::Session.active.find_by(session_id: session_id)
        return ::User.anonymous_user unless session

        session.extend_expiration if session.expires_at < 1.week.from_now
        session.user
      end
    end
  end
end
