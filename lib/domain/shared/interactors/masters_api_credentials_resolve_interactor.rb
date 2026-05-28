# frozen_string_literal: true

module Domain
  module Shared
    module Interactors
      # マスター API: API キー優先、なければセッション Cookie からログイン主体を解決する。
      class MastersApiCredentialsResolveInteractor
        def initialize(output_port:, api_key_principal_gateway:, session_cookie_principal_gateway:)
          @output_port = output_port
          @api_key_principal_gateway = api_key_principal_gateway
          @session_cookie_principal_gateway = session_cookie_principal_gateway
        end

        # @param input [Domain::Shared::Dtos::MastersApiCredentialsResolveInput]
        def call(input)
          if input.api_key_present?
            principal = @api_key_principal_gateway.principal_for_api_key(input.api_key)
            if principal.nil?
              @output_port.on_invalid_api_key
              return
            end

            @output_port.on_success(principal: principal)
            return
          end

          principal = @session_cookie_principal_gateway.principal_for_session_cookie(input.session_id)
          if principal.authenticated?
            @output_port.on_success(principal: principal)
          else
            @output_port.on_login_required
          end
        end
      end
    end
  end
end
