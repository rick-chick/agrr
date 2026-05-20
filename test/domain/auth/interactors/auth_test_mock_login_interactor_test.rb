# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Auth
    module Interactors
      class AuthTestMockLoginInteractorTest < DomainLibTestCase
        setup do
          @gateway = mock
          @appender = mock
          @port = mock
          @interactor = AuthTestMockLoginInteractor.new(
            output_port: @port,
            gateway: @gateway,
            oauth_url_appender: @appender
          )
          @input = Domain::Auth::Dtos::AuthTestMockLoginInput.new(
            google_id: "gid",
            email: "e",
            name: "n",
            avatar_source_url: "x",
            grant_admin: false,
            stashed_public_plan: false,
            pending_return_to: nil,
            pending_return_to_allowed: false
          )
        end

        test "environment not allowed" do
          @gateway.expects(:persist_mock_user_and_session!).never
          @port.expects(:on_environment_forbidden).once

          @interactor.call(input_dto: @input, environment_allowed: false)
        end

        test "blank google_id triggers missing mock" do
          input = Domain::Auth::Dtos::AuthTestMockLoginInput.new(
            google_id: "",
            email: "e",
            name: "n",
            avatar_source_url: "x",
            grant_admin: false,
            stashed_public_plan: false,
            pending_return_to: nil,
            pending_return_to_allowed: false
          )
          @port.expects(:on_missing_mock).once

          @interactor.call(input_dto: input, environment_allowed: true)
        end

        test "success without extras calls on_success_root" do
          expires = Time.utc(2026, 5, 8, 12, 0, 0)
          result = Domain::Auth::Dtos::AuthTestMockLoginPersistResult.new(
            status: :success,
            user_name: "U",
            session_id: "sess",
            expires_at: expires,
            error_messages: nil
          )
          @gateway.expects(:persist_mock_user_and_session!).with(@input).returns(result)
          @port.expects(:on_success_root).with(session_id: "sess", expires_at: expires, user_name: "U").once

          @interactor.call(input_dto: @input, environment_allowed: true)
        end

        test "success with stashed public plan" do
          input = Domain::Auth::Dtos::AuthTestMockLoginInput.new(
            google_id: "gid",
            email: "e",
            name: "n",
            avatar_source_url: "x",
            grant_admin: false,
            stashed_public_plan: true,
            pending_return_to: nil,
            pending_return_to_allowed: false
          )
          expires = Time.utc(2026, 1, 1)
          result = Domain::Auth::Dtos::AuthTestMockLoginPersistResult.new(
            status: :success,
            user_name: "U",
            session_id: "s",
            expires_at: expires,
            error_messages: nil
          )
          @gateway.expects(:persist_mock_user_and_session!).returns(result)
          @port.expects(:on_success_process_saved_plan).with(session_id: "s", expires_at: expires).once

          @interactor.call(input_dto: input, environment_allowed: true)
        end
      end
    end
  end
end
