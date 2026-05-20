# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain::CultivationPlan::Interactors::EntrySchedule
  class WindowServiceTest < DomainLibTestCase
    # まき/植えステージ（温度要件つき）の純 Ruby スナップショット。AR/factory 非依存。
    def ordered_stages
      tr = TemperatureRequirementSnapshot.new(
        frost_threshold: 0.0, optimal_min: 10.0, optimal_max: 30.0, base_temperature: nil
      )
      [
        CropStageSnapshot.new(id: 1, name: "播種", order: 1, temperature_requirement: tr),
        CropStageSnapshot.new(id: 2, name: "定植", order: 2, temperature_requirement: tr)
      ]
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
      result = WindowService.call(ordered_crop_stages: ordered_stages, weather_payload: { "data" => rows })

      assert result.eligible
      assert result.sowing_windows.any?
      assert_equal Date.new(2026, 4, 1), result.sowing_windows.first[:start_date]
      assert_equal Date.new(2026, 4, 5), result.sowing_windows.first[:end_date]
    end

    test "returns empty result when weather series is missing" do
      result = WindowService.call(ordered_crop_stages: ordered_stages, weather_payload: {})

      assert_not result.eligible
      assert_equal "no_weather_series", result.reason_parts[:error]
    end
  end
end
