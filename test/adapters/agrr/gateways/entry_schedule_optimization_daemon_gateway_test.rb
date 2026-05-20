# frozen_string_literal: true

require "test_helper"

module Adapters::Agrr::Gateways
  class EntryScheduleOptimizationGatewayTest < ActiveSupport::TestCase
    setup do
      @rows = (1..3).map do |d|
        {
          "time" => "2026-05-#{d.to_s.rjust(2, '0')}",
          "temperature_2m_min" => 8.0,
          "temperature_2m_max" => 22.0,
          "temperature_2m_mean" => 15.0
        }
      end
    end

    test "normalize_entry_weather_payload flattens nested data.data shape" do
      nested = {
        "data" => {
          "data" => @rows,
          "latitude" => 35.5,
          "longitude" => 139.7
        },
        "prediction_end_date" => "2026-12-31"
      }

      out = EntryScheduleOptimizationDaemonGateway.normalize_entry_weather_payload(nested)

      assert out["data"].is_a?(Array)
      assert_equal 3, out["data"].size
      assert_equal 35.5, out["latitude"].to_f
      assert_equal 139.7, out["longitude"].to_f
    end

    test "normalize_entry_weather_payload leaves flat payload unchanged" do
      flat = {
        "latitude" => 35.0,
        "longitude" => 139.0,
        "data" => @rows
      }
      out = EntryScheduleOptimizationDaemonGateway.normalize_entry_weather_payload(flat)

      assert_equal 3, out["data"].size
      assert_equal 35.0, out["latitude"].to_f
    end

    test "scale_stage_gdd_for_optimize_period scales down when sum exceeds cap" do
      req = {
        "stage_requirements" => [
          { "thermal" => { "required_gdd" => 800.0 } },
          { "thermal" => { "required_gdd" => 800.0 } }
        ]
      }
      out = EntryScheduleOptimizationDaemonGateway.scale_stage_gdd_for_optimize_period(req, max_total_gdd: 1000.0)
      stages = out["stage_requirements"]
      total = stages.sum { |s| s["thermal"]["required_gdd"].to_f }

      assert_in_delta 1000.0, total, 0.01
      assert_in_delta 500.0, stages[0]["thermal"]["required_gdd"].to_f, 0.01
    end

    test "evaluation_range intersects last-june through next-june with weather dates" do
      crop = create(:crop, :reference, :with_stages, region: "jp")
      nested = {
        "data" => {
          "data" => @rows,
          "latitude" => 35.0,
          "longitude" => 139.0
        }
      }

      travel_to Time.zone.parse("2026-06-15") do
        svc = EntryScheduleOptimizationDaemonGateway.new(crop: crop, weather_payload: nested, farm: nil, crop_gateway: CompositionRoot.crop_gateway)
        range = svc.send(:evaluation_range)

        assert_equal Date.new(2026, 5, 1), range[0]
        assert_equal Date.new(2026, 5, 3), range[1]
      end
    end
  end
end
