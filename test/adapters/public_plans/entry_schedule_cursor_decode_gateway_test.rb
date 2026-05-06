# frozen_string_literal: true

require "test_helper"
require "base64"

class Adapters::PublicPlans::EntryScheduleCursorDecodeGatewayTest < ActiveSupport::TestCase
  setup do
    @gateway = Adapters::PublicPlans::EntryScheduleCursorDecodeGateway.new
  end

  test "decodes valid cursor" do
    raw = Base64.urlsafe_encode64({ "o" => 10 }.to_json)
    assert_equal 10, @gateway.decode(raw)
  end

  test "returns nil for garbage" do
    assert_nil @gateway.decode("%%%")
    assert_nil @gateway.decode("")
    assert_nil @gateway.decode(nil)
  end
end
