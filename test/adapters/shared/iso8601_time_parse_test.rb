# frozen_string_literal: true

require "test_helper"

class Adapters::Shared::Iso8601TimeParseTest < ActiveSupport::TestCase
  test "parses ISO8601 string in application zone" do
    Time.use_zone("Tokyo") do
      t = Adapters::Shared::Iso8601TimeParse.parse_in_application_zone("2024-06-01T12:00:00Z")
      assert_equal Time.utc(2024, 6, 1, 12, 0, 0).in_time_zone("Tokyo"), t
    end
  end

  test "returns nil for invalid string" do
    assert_nil Adapters::Shared::Iso8601TimeParse.parse_in_application_zone("not-a-time")
  end
end
