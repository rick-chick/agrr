# frozen_string_literal: true

require "test_helper"

class Adapters::Shared::Gateways::UserActiveRecordGatewayTest < ActiveSupport::TestCase
  test "find returns user when present" do
    user = create(:user)
    gw = Adapters::Shared::Gateways::UserActiveRecordGateway.new

    assert_equal user.id, gw.find(user.id).id
  end

  test "find raises Domain::Shared::Exceptions::RecordNotFound when missing" do
    gw = Adapters::Shared::Gateways::UserActiveRecordGateway.new

    assert_raises(Domain::Shared::Exceptions::RecordNotFound) do
      gw.find(9_999_999_999)
    end
  end
end
