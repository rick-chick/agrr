# frozen_string_literal: true

require "test_helper"

class Adapters::Shared::Gateways::SessionCookieUserActiveRecordGatewayTest < ActiveSupport::TestCase
  setup do
    @gateway = Adapters::Shared::Gateways::SessionCookieUserActiveRecordGateway.new
  end

  test "nil session_id returns anonymous user" do
    user = @gateway.user_for_session_cookie(nil)

    assert user.anonymous?
  end

  test "invalid session_id format returns anonymous user" do
    user = @gateway.user_for_session_cookie("not-a-valid-session-id")

    assert user.anonymous?
  end

  test "valid format but unknown session returns anonymous user" do
    unknown_id = Session.generate_session_id
    assert Session.active.find_by(session_id: unknown_id).nil?

    user = @gateway.user_for_session_cookie(unknown_id)

    assert user.anonymous?
  end

  test "active session returns its user" do
    user = create(:user)
    session = Session.create_for_user(user)

    resolved = @gateway.user_for_session_cookie(session.session_id)

    assert_equal user.id, resolved.id
    refute resolved.anonymous?
  end

  test "extends expiration when session expires within one week" do
    user = create(:user)
    session = create(:session, :expiring_soon, user: user)

    before = session.expires_at
    @gateway.user_for_session_cookie(session.session_id)
    session.reload

    assert session.expires_at > before
    assert_operator session.expires_at, :>, 1.week.from_now
  end
end
