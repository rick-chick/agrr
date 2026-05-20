# frozen_string_literal: true

module Adapters
  module Shared
    module Gateways
      class AuthTestLoginActiveRecordGateway
        include Domain::Auth::Gateways::AuthTestLoginGateway

        # @param input_dto [Domain::Auth::Dtos::AuthTestMockLoginInput]
        # @return [Domain::Auth::Dtos::AuthTestMockLoginPersistResult]
        def persist_mock_user_and_session!(input_dto)
          processed_avatar = ::User.process_avatar_url(input_dto.avatar_source_url)
          user = ::User.find_or_create_by(google_id: input_dto.google_id) do |u|
            u.email = input_dto.email
            u.name = input_dto.name
            u.avatar_url = processed_avatar
            u.admin = input_dto.grant_admin
          end

          unless user.persisted?
            return Domain::Auth::Dtos::AuthTestMockLoginPersistResult.new(
              status: :user_not_persisted,
              error_messages: user.errors.full_messages
            )
          end

          if user.persisted? && input_dto.grant_admin && !user.admin?
            user.update!(admin: true)
          end

          user_session = ::Session.create_for_user(user)
          Domain::Auth::Dtos::AuthTestMockLoginPersistResult.new(
            status: :success,
            user_name: user.name,
            session_id: user_session.session_id,
            expires_at: user_session.expires_at
          )
        rescue ActiveRecord::RecordInvalid => e
          Domain::Auth::Dtos::AuthTestMockLoginPersistResult.new(
            status: :record_invalid,
            error_messages: [ e.message ]
          )
        end
      end
    end
  end
end
