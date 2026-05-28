# frozen_string_literal: true

module Adapters
  module Shared
    module Gateways
      # Resolves `User` from the browser session cookie value (ActiveRecord stays in this adapter).
      # Shared by HTML `ApplicationController#current_user`.
      class SessionCookieUserActiveRecordGateway
        # @param session_id [String, nil] raw cookie value
        # @return [Adapters::Shared::Dtos::SessionUserDto] non-AR DTO for the session user
        def user_for_session_cookie(session_id)
          user = SessionCookieUserResolution.resolve_ar_user(session_id)
          build_dto(user)
        end

        private

        def build_dto(user)
          Adapters::Shared::Dtos::SessionUserDto.new(
            id: user.id,
            name: user.name,
            email: user.email,
            avatar_url: user.avatar_url,
            admin: user.admin?,
            anonymous: user.anonymous?
          )
        end
      end
    end
  end
end
