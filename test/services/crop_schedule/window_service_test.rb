# frozen_string_literal: true

require "test_helper"

module Domain::CultivationPlan::Interactors::EntrySchedule
  class WindowServiceTest < ActiveSupport::TestCase
    setup do
      @crop = create(:crop, :reference, :with_stages, region: "jp")
    end

    test "returns merged sowing windows when daily weather satisfies thresholds" do
      rows = (1..5).map do |d|
        {
          "time" => "2026-04-#{d.to_s.rjust(2, '0')}",
          "temperature_2m_min" => 5.0,
          "temperature_2m_max" => 28.0,
          "temperature_2m_mean" => 19.0
        }
      end
      payload = { "data" => rows }

      result = WindowService.call(crop: @crop.reload, weather_payload: payload)

      assert result.eligible
      assert result.sowing_windows.any?
      assert_equal result.sowing_windows.first[:start_date], Date.new(2026, 4, 1)
      assert_equal result.sowing_windows.first[:end_date], Date.new(2026, 4, 5)
    end

    test "returns empty result when weather series is missing" do
      result = WindowService.call(crop: @crop, weather_payload: {})

      assert_not result.eligible
      assert_equal "no_weather_series", result.reason_parts[:error]
    end
  end
end
