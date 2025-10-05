# frozen_string_literal: true

require "test_helper"

class UserTest < ActiveSupport::TestCase
  def setup
    @user = User.new(
      email: "test@example.com",
      name: "Test User",
      google_id: "google123456789",
      avatar_url: "https://example.com/avatar.jpg"
    )
  end

  test "should be valid" do
    assert @user.valid?
  end

  test "email should be present" do
    @user.email = nil
    assert_not @user.valid?
  end

  test "email should be unique" do
    duplicate_user = @user.dup
    @user.save
    assert_not duplicate_user.valid?
  end

  test "email should be valid format" do
    valid_emails = %w[user@example.com USER@foo.COM A_US-ER@foo.bar.org
                      first.last@foo.jp alice+bob@baz.cn]
    valid_emails.each do |valid_email|
      @user.email = valid_email
      assert @user.valid?, "#{valid_email.inspect} should be valid"
    end
  end

  test "email should reject invalid formats" do
    invalid_emails = %w[user@example,com user_at_foo.org user.name@example.
                        foo@bar_baz.com foo@bar+baz.com]
    invalid_emails.each do |invalid_email|
      @user.email = invalid_email
      assert_not @user.valid?, "#{invalid_email.inspect} should be invalid"
    end
  end

  test "name should be present" do
    @user.name = "   "
    assert_not @user.valid?
  end

  test "name should not be too long" do
    @user.name = "a" * 51
    assert_not @user.valid?
  end

  test "google_id should be present" do
    @user.google_id = nil
    assert_not @user.valid?
  end

  test "google_id should be unique" do
    duplicate_user = @user.dup
    @user.save
    duplicate_user.email = "different@example.com"
    assert_not duplicate_user.valid?
  end

  test "should find or create user from omniauth" do
    auth_hash = {
      'provider' => 'google_oauth2',
      'uid' => 'google123456789',
      'info' => {
        'email' => 'oauth@example.com',
        'name' => 'OAuth User',
        'image' => 'https://example.com/oauth_avatar.jpg'
      }
    }

    user = User.from_omniauth(auth_hash)
    assert user.persisted?
    assert_equal 'oauth@example.com', user.email
    assert_equal 'OAuth User', user.name
    assert_equal 'google123456789', user.google_id
    assert_equal 'https://example.com/oauth_avatar.jpg', user.avatar_url
  end

  test "should find existing user from omniauth" do
    existing_user = User.create!(
      email: 'existing@example.com',
      name: 'Existing User',
      google_id: 'google_existing',
      avatar_url: 'https://example.com/existing.jpg'
    )

    auth_hash = {
      'provider' => 'google_oauth2',
      'uid' => 'google_existing',
      'info' => {
        'email' => 'existing@example.com',
        'name' => 'Updated Name',
        'image' => 'https://example.com/updated.jpg'
      }
    }

    user = User.from_omniauth(auth_hash)
    assert_equal existing_user.id, user.id
    assert_equal 'Updated Name', user.name
    assert_equal 'https://example.com/updated.jpg', user.avatar_url
  end

  test "should handle invalid omniauth data" do
    auth_hash = {
      'provider' => 'google_oauth2',
      'uid' => nil,
      'info' => {}
    }

    assert_raises(ActiveRecord::RecordInvalid) do
      User.from_omniauth(auth_hash)
    end
  end
end

