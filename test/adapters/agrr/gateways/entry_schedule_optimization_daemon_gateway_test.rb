# frozen_string_literal: true

require "test_helper"

module Adapters::Agrr::Gateways
  class EntryScheduleOptimizationDaemonGatewayTest < ActiveSupport::TestCase
    test "optimize_period delegates to OptimizationDaemonGateway and returns parsed hash" do
      crop = create(:crop, :reference, :with_stages, region: "jp")
      weather = {
        "latitude" => 35.0,
        "longitude" => 139.0,
        "data" => [
          { "time" => "2026-05-01", "temperature_2m_mean" => 15.0 }
        ]
      }
      requirement = { "stage_requirements" => [] }
      expected = {
        start_date: Date.new(2026, 5, 1),
        completion_date: Date.new(2026, 5, 10),
        days: 10,
        gdd: 100.0,
        cost: 1.0
      }

      inner = mock
      inner.expects(:optimize).with(
        crop_name: crop.name,
        crop_variety: crop.variety.presence || "general",
        weather_data: weather,
        field_area: 1.0,
        daily_fixed_cost: 0.01,
        evaluation_start: Date.new(2026, 5, 1),
        evaluation_end: Date.new(2026, 5, 31),
        crop_requirement: requirement,
        crop: crop
      ).returns(expected)

      ::Adapters::Agrr::Gateways::OptimizationDaemonGateway.expects(:new).returns(inner)

      result = EntryScheduleOptimizationDaemonGateway.new.optimize_period(
        crop_name: crop.name,
        crop_variety: crop.variety.presence || "general",
        weather_data: weather,
        evaluation_start: Date.new(2026, 5, 1),
        evaluation_end: Date.new(2026, 5, 31),
        crop_requirement: requirement,
        crop: crop
      )

      assert_equal expected, result
    end

    test "optimize_period raises EntryScheduleOptimizationError when daemon is not running" do
      inner = mock
      inner.expects(:optimize).raises(
        ::Adapters::Agrr::Gateways::DaemonClient::DaemonNotRunningError.new("down")
      )
      ::Adapters::Agrr::Gateways::OptimizationDaemonGateway.expects(:new).returns(inner)

      error = assert_raises(Domain::CultivationPlan::Errors::EntryScheduleOptimizationError) do
        EntryScheduleOptimizationDaemonGateway.new.optimize_period(
          crop_name: "c",
          crop_variety: "v",
          weather_data: {},
          evaluation_start: Date.new(2026, 1, 1),
          evaluation_end: Date.new(2026, 12, 31),
          crop_requirement: {},
          crop: nil
        )
      end

      assert_equal :daemon_unavailable, error.error_key
    end
  end
end
