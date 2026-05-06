# frozen_string_literal: true

require "test_helper"

class Adapters::Shared::Iso8601CalendarDateTest < ActiveSupport::TestCase
  test "parses valid YYYY-MM-DD" do
    d = Adapters::Shared::Iso8601CalendarDate.parse("2024-03-15")
    assert_equal Date.new(2024, 3, 15), d
  end

  test "returns nil for invalid calendar date" do
    assert_nil Adapters::Shared::Iso8601CalendarDate.parse("2024-02-30")
  end

  test "returns nil for bad format" do
    assert_nil Adapters::Shared::Iso8601CalendarDate.parse("03/15/2024")
  end
end
