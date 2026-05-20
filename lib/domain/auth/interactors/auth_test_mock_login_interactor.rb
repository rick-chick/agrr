# frozen_string_literal: true

module Domain
  module Auth
    module Interactors
      class AuthTestMockLoginInteractor
        def initialize(output_port:, gateway:, oauth_url_appender:)
          @output_port = output_port
          @gateway = gateway
          @oauth_url_appender = oauth_url_appender
        end

        def call(input_dto:, environment_allowed:)
          unless environment_allowed
            @output_port.on_environment_forbidden
            return
          end

          if input_dto.google_id.nil? || input_dto.google_id.empty?
            @output_port.on_missing_mock
            return
          end

          result = @gateway.persist_mock_user_and_session!(input_dto)

          case result.status
          when :success
            if input_dto.stashed_public_plan
              @output_port.on_success_process_saved_plan(session_id: result.session_id, expires_at: result.expires_at)
            elsif input_dto.pending_return_to && input_dto.pending_return_to_allowed
              url = @oauth_url_appender.append(input_dto.pending_return_to)
              @output_port.on_success_return_to(
                url: url,
                session_id: result.session_id,
                expires_at: result.expires_at,
                user_name: result.user_name
              )
            else
              @output_port.on_success_root(
                session_id: result.session_id,
                expires_at: result.expires_at,
                user_name: result.user_name
              )
            end
          when :user_not_persisted, :record_invalid
            messages = Array(result.error_messages).compact
            @output_port.on_create_failed(error_messages: messages)
          else
            @output_port.on_create_failed(error_messages: [ "unknown" ])
          end
        end
      end
    end
  end
end
