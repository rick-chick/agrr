# frozen_string_literal: true

module Adapters
  module Shared
    module Gateways
      AuthTestMockLoginPersistResult = Struct.new(
        :status,
        :user_name,
        :session_id,
        :expires_at,
        :error_messages,
        keyword_init: true
      )

      class AuthTestLoginActiveRecordGateway
        # @param input [Adapters::Auth::AuthTestMockLoginInput]
        # @return [AuthTestMockLoginPersistResult]
        def persist_mock_user_and_session!(input)
          processed_avatar = ::User.process_avatar_url(input.avatar_source_url)
          user = ::User.find_or_create_by(google_id: input.google_id) do |u|
            u.email = input.email
            u.name = input.name
            u.avatar_url = processed_avatar
            u.admin = input.grant_admin
          end

          unless user.persisted?
            return AuthTestMockLoginPersistResult.new(
              status: :user_not_persisted,
              error_messages: user.errors.full_messages
            )
          end

          user.update!(admin: true) if input.grant_admin && !user.admin?

          user_session = ::Session.create_for_user(user)
          AuthTestMockLoginPersistResult.new(
            status: :success,
            user_name: user.name,
            session_id: user_session.session_id,
            expires_at: user_session.expires_at
          )
        rescue ActiveRecord::RecordInvalid => e
          AuthTestMockLoginPersistResult.new(
            status: :record_invalid,
            error_messages: [ e.message ]
          )
        end
      end
    end
  end
end
