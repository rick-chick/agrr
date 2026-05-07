# frozen_string_literal: true

require "test_helper"

module Domain
  module Auth
    module Interactors
      class AuthUserLogoutInteractorTest < ActiveSupport::TestCase
        setup do
          @gateway = mock
          @port = mock
        end

        test "when not authenticated only notifies not logged in" do
          @gateway.expects(:destroy_all_sessions_for_user!).never
          @port.expects(:on_not_logged_in).once
          @port.expects(:on_success).never

          AuthUserLogoutInteractor.new(
            output_port: @port,
            session_revocation_gateway: @gateway
          ).call(authenticated: false, user_id: 1)
        end

        test "when authenticated revokes then success" do
          @gateway.expects(:destroy_all_sessions_for_user!).with(user_id: 42).once
          @port.expects(:on_success).once
          @port.expects(:on_not_logged_in).never

          AuthUserLogoutInteractor.new(
            output_port: @port,
            session_revocation_gateway: @gateway
          ).call(authenticated: true, user_id: 42)
        end
      end
    end
  end
end
