# frozen_string_literal: true

require "test_helper"

class SessionTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: 'test@example.com',
      name: 'Test User',
      google_id: 'google123456789',
      avatar_url: 'https://example.com/avatar.jpg'
    )
  end

  test "should be valid" do
    session = Session.new(
      session_id: Session.generate_session_id,
      user: @user,
      expires_at: 2.weeks.from_now
    )
    assert session.valid?
  end

  test "should require session_id" do
    session = Session.new(
      user: @user,
      expires_at: 2.weeks.from_now
    )
    assert_not session.valid?
  end

  test "should require unique session_id" do
    session_id = Session.generate_session_id
    Session.create!(
      session_id: session_id,
      user: @user,
      expires_at: 2.weeks.from_now
    )
    
    duplicate_session = Session.new(
      session_id: session_id,
      user: @user,
      expires_at: 2.weeks.from_now
    )
    assert_not duplicate_session.valid?
  end

  test "should require user" do
    session = Session.new(
      session_id: Session.generate_session_id,
      expires_at: 2.weeks.from_now
    )
    assert_not session.valid?
  end

  test "should require expires_at" do
    session = Session.new(
      session_id: Session.generate_session_id,
      user: @user
    )
    assert_not session.valid?
  end

  test "should generate valid session_id" do
    session_id = Session.generate_session_id
    assert Session.valid_session_id?(session_id)
    assert_equal 43, session_id.length
  end

  test "should validate session_id format" do
    valid_ids = [
      Session.generate_session_id,
      "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"
    ]
    
    valid_ids.each do |id|
      assert Session.valid_session_id?(id), "#{id} should be valid"
    end
  end

  test "should reject invalid session_id format" do
    invalid_ids = [
      nil,
      "",
      "short",
      "a" * 100,
      "invalid@characters!",
      "spaces in id",
      "newline\nid"
    ]
    
    invalid_ids.each do |id|
      assert_not Session.valid_session_id?(id), "#{id.inspect} should be invalid"
    end
  end

  test "should create session for user" do
    assert_difference 'Session.count', 1 do
      session = Session.create_for_user(@user)
      assert session.persisted?
      assert_equal @user, session.user
      assert session.expires_at > Time.current
    end
  end

  test "should check if session is expired" do
    session = Session.create!(
      session_id: Session.generate_session_id,
      user: @user,
      expires_at: 1.day.ago
    )
    assert session.expired?
    
    session.update!(expires_at: 1.day.from_now)
    assert_not session.expired?
  end

  test "should extend session expiration" do
    session = Session.create!(
      session_id: Session.generate_session_id,
      user: @user,
      expires_at: 1.hour.from_now
    )
    
    original_expiry = session.expires_at
    session.extend_expiration
    
    assert session.expires_at > original_expiry
    assert session.expires_at > 1.week.from_now
  end

  test "should find active sessions" do
    active_session = Session.create!(
      session_id: Session.generate_session_id,
      user: @user,
      expires_at: 1.day.from_now
    )
    
    expired_session = Session.create!(
      session_id: Session.generate_session_id,
      user: @user,
      expires_at: 1.day.ago
    )
    
    active_sessions = Session.active
    assert_includes active_sessions, active_session
    assert_not_includes active_sessions, expired_session
  end

  test "should find expired sessions" do
    active_session = Session.create!(
      session_id: Session.generate_session_id,
      user: @user,
      expires_at: 1.day.from_now
    )
    
    expired_session = Session.create!(
      session_id: Session.generate_session_id,
      user: @user,
      expires_at: 1.day.ago
    )
    
    expired_sessions = Session.expired
    assert_includes expired_sessions, expired_session
    assert_not_includes expired_sessions, active_session
  end

  test "should cleanup expired sessions" do
    # Create active and expired sessions
    Session.create!(
      session_id: Session.generate_session_id,
      user: @user,
      expires_at: 1.day.from_now
    )
    
    expired_session = Session.create!(
      session_id: Session.generate_session_id,
      user: @user,
      expires_at: 1.day.ago
    )
    
    assert_difference 'Session.count', -1 do
      Session.cleanup_expired
    end
    
    assert_not Session.exists?(expired_session.id)
  end

  test "should destroy dependent sessions when user is destroyed" do
    session = Session.create_for_user(@user)
    
    assert_difference 'Session.count', -1 do
      @user.destroy
    end
  end
end

