# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Shared
    module Interactors
      class MastersApiCredentialsResolveInteractorTest < DomainLibTestCase
        setup do
          @api_key_gateway = mock
          @session_gateway = mock
          @port = mock
          @interactor = MastersApiCredentialsResolveInteractor.new(
            output_port: @port,
            api_key_principal_gateway: @api_key_gateway,
            session_cookie_principal_gateway: @session_gateway
          )
        end

        test "valid api key resolves via api key gateway" do
          principal = principal_stub(authenticated: true)
          @api_key_gateway.expects(:principal_for_api_key).with("key-1").returns(principal)
          @session_gateway.expects(:principal_for_session_cookie).never
          @port.expects(:on_success).with(principal: principal).once
          @port.expects(:on_invalid_api_key).never
          @port.expects(:on_login_required).never

          @interactor.call(input_dto(api_key: "key-1", session_id: "sess-ignored"))
        end

        test "invalid api key notifies invalid key" do
          @api_key_gateway.expects(:principal_for_api_key).with("bad").returns(nil)
          @session_gateway.expects(:principal_for_session_cookie).never
          @port.expects(:on_invalid_api_key).once
          @port.expects(:on_success).never
          @port.expects(:on_login_required).never

          @interactor.call(input_dto(api_key: "bad", session_id: nil))
        end

        test "no api key uses session gateway when authenticated" do
          principal = principal_stub(authenticated: true)
          @api_key_gateway.expects(:principal_for_api_key).never
          @session_gateway.expects(:principal_for_session_cookie).with("sess-1").returns(principal)
          @port.expects(:on_success).with(principal: principal).once
          @port.expects(:on_login_required).never

          @interactor.call(input_dto(api_key: nil, session_id: "sess-1"))
        end

        test "no api key and anonymous session requires login" do
          principal = principal_stub(authenticated: false)
          @api_key_gateway.expects(:principal_for_api_key).never
          @session_gateway.expects(:principal_for_session_cookie).with(nil).returns(principal)
          @port.expects(:on_login_required).once
          @port.expects(:on_success).never

          @interactor.call(input_dto(api_key: "", session_id: nil))
        end

        test "whitespace only api key skips api key gateway and uses session" do
          principal = principal_stub(authenticated: false)
          @api_key_gateway.expects(:principal_for_api_key).never
          @session_gateway.expects(:principal_for_session_cookie).with("sess-1").returns(principal)
          @port.expects(:on_login_required).once

          @interactor.call(input_dto(api_key: "   ", session_id: "sess-1"))
        end

        private

        def input_dto(api_key:, session_id:)
          Dtos::MastersApiCredentialsResolveInput.new(api_key: api_key, session_id: session_id)
        end

        def principal_stub(authenticated:)
          Dtos::SessionPrincipal.new(
            id: 1,
            email: "u@example.com",
            name: "User",
            admin: false,
            anonymous: !authenticated,
            api_key: nil
          )
        end
      end
    end
  end
end
