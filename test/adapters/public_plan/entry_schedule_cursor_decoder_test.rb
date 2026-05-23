# frozen_string_literal: true

require "test_helper"
require "base64"

class Adapters::PublicPlan::EntryScheduleCursorDecoderTest < ActiveSupport::TestCase
  setup do
    @decoder = Adapters::PublicPlan::EntryScheduleCursorDecoder.new
  end

  test "decodes valid cursor" do
    raw = Base64.urlsafe_encode64({ "o" => 10 }.to_json)
    assert_equal 10, @decoder.decode(raw)
  end

  test "returns nil for garbage" do
    assert_nil @decoder.decode("%%%")
    assert_nil @decoder.decode("")
    assert_nil @decoder.decode(nil)
  end
end
