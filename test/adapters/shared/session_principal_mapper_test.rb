# frozen_string_literal: true

require "test_helper"

class Adapters::Shared::SessionPrincipalMapperTest < ActiveSupport::TestCase
  test "from_user maps attributes to SessionPrincipal" do
    user = create(:user, :admin)

    principal = Adapters::Shared::SessionPrincipalMapper.from_user(user)

    assert_instance_of Domain::Shared::Dtos::SessionPrincipal, principal
    assert_equal user.id, principal.id
    assert_equal user.email, principal.email
    assert_equal user.name, principal.name
    assert principal.admin?
    refute principal.anonymous?
    assert principal.authenticated?
  end

  test "from_user maps anonymous user" do
    user = User.anonymous_user

    principal = Adapters::Shared::SessionPrincipalMapper.from_user(user)

    assert principal.anonymous?
    refute principal.authenticated?
  end
end
