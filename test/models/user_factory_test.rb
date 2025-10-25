# frozen_string_literal: true

require "test_helper"

class UserFactoryTest < ActiveSupport::TestCase
  test "create basic user" do
    user = create(:user)
    assert user.persisted?
    assert_not user.is_anonymous?
    assert user.email.present?
  end

  test "create admin user" do
    admin = create(:user, :admin)
    assert admin.admin?
  end

  test "create user with session" do
    user = create(:user)
    session = create(:session, user: user)
    assert user.persisted?
    assert session.persisted?
    assert_equal user, session.user
  end

  test "create multiple users with unique emails" do
    user1 = create(:user)
    user2 = create(:user)
    user3 = create(:user)
    
    assert_not_equal user1.email, user2.email
    assert_not_equal user2.email, user3.email
    assert_not_equal user1.email, user3.email
  end

  test "create anonymous user" do
    anonymous = create(:user, :anonymous)
    assert anonymous.is_anonymous?
    assert_nil anonymous.email
    assert_nil anonymous.name
  end

  test "create user with farm and field" do
    user = create(:user)
    farm = create(:farm, user: user)
    field = create(:field, farm: farm, user: user)
    
    assert_equal user, farm.user
    assert_equal user, field.user
    assert_equal farm, field.farm
  end
end

