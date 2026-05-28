# frozen_string_literal: true

require "test_helper"

class Adapters::Shared::Gateways::ApiKeyPrincipalActiveRecordGatewayTest < ActiveSupport::TestCase
  setup do
    @gateway = Adapters::Shared::Gateways::ApiKeyPrincipalActiveRecordGateway.new
  end

  test "maps user resolved by api key to SessionPrincipal" do
    user = create(:user)
    user.generate_api_key!

    principal = @gateway.principal_for_api_key(user.api_key)

    assert_instance_of Domain::Shared::Dtos::SessionPrincipal, principal
    assert_equal user.id, principal.id
    assert_equal user.email, principal.email
    refute principal.anonymous?
    assert principal.authenticated?
  end
end
