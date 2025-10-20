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

  test "process_avatar_url should extract filename from local asset path" do
    # ローカルアセットパスからファイル名を抽出
    assert_equal 'dev-avatar.svg', User.process_avatar_url('/assets/dev-avatar.svg')
    assert_equal 'farm-avatar.svg', User.process_avatar_url('/assets/farm-avatar.svg')
  end

  test "process_avatar_url should keep external URLs unchanged" do
    # 外部URLはそのまま保持
    external_url = 'https://lh3.googleusercontent.com/a/example'
    assert_equal external_url, User.process_avatar_url(external_url)
  end

  test "process_avatar_url should handle nil" do
    # nilはnilを返す
    assert_nil User.process_avatar_url(nil)
  end

  test "process_avatar_url should handle blank string" do
    # 空文字列はnilを返す
    assert_nil User.process_avatar_url('')
  end

  test "from_omniauth should convert local avatar paths to filenames" do
    auth_hash = {
      'provider' => 'google_oauth2',
      'uid' => 'google_local_avatar',
      'info' => {
        'email' => 'local@example.com',
        'name' => 'Local Avatar User',
        'image' => '/assets/dev-avatar.svg'
      }
    }

    user = User.from_omniauth(auth_hash)
    assert_equal 'dev-avatar.svg', user.avatar_url
  end

  test "avatar_url validation should accept SVG filenames" do
    @user.avatar_url = 'dev-avatar.svg'
    assert @user.valid?
    
    @user.avatar_url = 'farm-avatar.svg'
    assert @user.valid?
  end

  test "avatar_url validation should reject full paths" do
    @user.avatar_url = '/assets/dev-avatar.svg'
    assert_not @user.valid?
    assert_includes @user.errors[:avatar_url], "must be a valid URL or SVG filename"
  end

  test "avatar_url validation should accept external URLs" do
    @user.avatar_url = 'https://lh3.googleusercontent.com/a/example'
    assert @user.valid?
  end

  # Anonymous user tests
  test "anonymous user should be valid without email, name, or google_id" do
    anonymous = User.new(is_anonymous: true)
    assert anonymous.valid?
  end

  test "anonymous user should not require email" do
    anonymous = User.new(is_anonymous: true, email: nil)
    assert anonymous.valid?
  end

  test "anonymous user should not require name" do
    anonymous = User.new(is_anonymous: true, name: nil)
    assert anonymous.valid?
  end

  test "anonymous user should not require google_id" do
    anonymous = User.new(is_anonymous: true, google_id: nil)
    assert anonymous.valid?
  end

  test "non-anonymous user should require email" do
    user = User.new(is_anonymous: false, name: "Test", google_id: "123")
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "non-anonymous user should require name" do
    user = User.new(is_anonymous: false, email: "test@example.com", google_id: "123")
    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end

  test "non-anonymous user should require google_id" do
    user = User.new(is_anonymous: false, email: "test@example.com", name: "Test")
    assert_not user.valid?
    assert_includes user.errors[:google_id], "can't be blank"
  end

  test "is_anonymous? should return true for anonymous user" do
    anonymous = User.new(is_anonymous: true)
    assert anonymous.is_anonymous?
  end

  test "is_anonymous? should return false for non-anonymous user" do
    assert_not @user.is_anonymous?
  end

  test "anonymous? should return true for anonymous user" do
    anonymous = User.new(is_anonymous: true)
    assert anonymous.anonymous?
  end

  test "anonymous? should return false for non-anonymous user" do
    assert_not @user.anonymous?
  end

  test "anonymous_user should return or create anonymous user" do
    # Clear class variable for testing
    User.instance_variable_set(:@anonymous_user, nil)
    
    anonymous = User.anonymous_user
    assert anonymous.is_anonymous?
    assert anonymous.persisted?
    
    # Should return the same instance on subsequent calls
    same_anonymous = User.anonymous_user
    assert_equal anonymous.id, same_anonymous.id
  end

  test "multiple anonymous users with different emails should be allowed" do
    anonymous1 = User.create!(is_anonymous: true, email: "anon1@example.com")
    anonymous2 = User.create!(is_anonymous: true, email: "anon2@example.com")
    
    assert anonymous1.valid?
    assert anonymous2.valid?
    assert_not_equal anonymous1.id, anonymous2.id
  end

  test "multiple anonymous users with nil email should be allowed" do
    anonymous1 = User.create!(is_anonymous: true, email: nil)
    anonymous2 = User.create!(is_anonymous: true, email: nil)
    
    assert anonymous1.valid?
    assert anonymous2.valid?
    assert_not_equal anonymous1.id, anonymous2.id
  end

  # Associations tests
  test "should have many farms" do
    user = users(:developer)
    assert_respond_to user, :farms
    assert_kind_of ActiveRecord::Associations::CollectionProxy, user.farms
  end

  test "should have many crops" do
    user = users(:developer)
    assert_respond_to user, :crops
    assert_kind_of ActiveRecord::Associations::CollectionProxy, user.crops
  end

  test "should have many cultivation_plans" do
    user = users(:developer)
    assert_respond_to user, :cultivation_plans
    assert_kind_of ActiveRecord::Associations::CollectionProxy, user.cultivation_plans
  end

  test "should have many interaction_rules" do
    user = users(:developer)
    assert_respond_to user, :interaction_rules
    assert_kind_of ActiveRecord::Associations::CollectionProxy, user.interaction_rules
  end
end

