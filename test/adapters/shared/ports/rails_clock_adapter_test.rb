# frozen_string_literal: true

require "test_helper"

class Adapters::Shared::Ports::RailsClockAdapterTest < ActiveSupport::TestCase
  test "today returns Time.zone.today" do
    travel_to Time.zone.local(2024, 7, 4, 12, 0, 0) do
      adapter = Adapters::Shared::Ports::RailsClockAdapter.new
      assert_equal Date.new(2024, 7, 4), adapter.today
    end
  end
end
