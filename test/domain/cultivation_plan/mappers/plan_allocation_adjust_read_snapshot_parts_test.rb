# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Mappers
      class PlanAllocationAdjustReadSnapshotPartsTest < DomainLibTestCase
        Parts = PlanAllocationAdjustReadSnapshotParts
        Snapshot = Dtos::PlanAllocationAdjustReadSnapshot
        FieldCultivationSnapshot = Dtos::PlanAllocationAdjustFieldCultivationSnapshot

        test "build_field_source_snapshots normalizes optimize-style optimization_result keys" do
          plan_field_snapshots = [
            Snapshot::PlanFieldSnapshot.new(id: 2, name: "North", area: 100.0, daily_fixed_cost: 5.0)
          ]
          field_cultivation = FieldCultivationSnapshot.new(
            field_cultivation_id: 10,
            field_id: 2,
            crop_id: 5,
            crop_name: "Tomato",
            variety: nil,
            area: 12.0,
            start_date: Date.new(2026, 4, 1),
            completion_date: Date.new(2026, 4, 20),
            stored_cultivation_days: 20,
            crop_stage_count: 1,
            estimated_cost: 100.0,
            optimization_result: {
              "expected_revenue" => 200.0,
              "profit" => 100.0,
              "raw" => { "total_gdd" => 42.0 }
            }
          )

          snapshots = Parts.build_field_source_snapshots(
            plan_field_snapshots: plan_field_snapshots,
            field_cultivation_snapshots: [ field_cultivation ]
          )
          source = snapshots.first.cultivations.first

          assert_in_delta 200.0, source.revenue, 0.001
          assert_in_delta 42.0, source.accumulated_gdd, 0.001
          assert_equal 20, source.cultivation_days
          assert source.has_growth_stages
        end

        test "build_field_source_snapshots derives cultivation_days when stored is nil" do
          plan_field_snapshots = [
            Snapshot::PlanFieldSnapshot.new(id: 1, name: "A", area: 10.0, daily_fixed_cost: 1.0)
          ]
          field_cultivation = FieldCultivationSnapshot.new(
            field_cultivation_id: 1,
            field_id: 1,
            crop_id: 1,
            crop_name: "C",
            variety: nil,
            area: 1.0,
            start_date: Date.new(2026, 1, 1),
            completion_date: Date.new(2026, 1, 10),
            stored_cultivation_days: nil,
            crop_stage_count: 0,
            estimated_cost: nil,
            optimization_result: nil
          )

          source = Parts.build_field_source_snapshots(
            plan_field_snapshots: plan_field_snapshots,
            field_cultivation_snapshots: [ field_cultivation ]
          ).first.cultivations.first

          assert_equal 10, source.cultivation_days
          refute source.has_growth_stages
          assert_in_delta 0.0, source.estimated_cost, 0.001
        end

        test "plan_crop_snapshot invokes build_agrr_requirement only when crop has growth stages" do
          called = false
          entry = Parts.plan_crop_snapshot(
            crop_id: 1,
            crop_name: "Tomato",
            groups: [],
            crop_stage_count: 2,
            build_agrr_requirement: -> { called = true; { "stages" => [] } }
          )

          assert called
          assert entry.has_growth_stages
          assert_equal({ "stages" => [] }, entry.agrr_requirement)

          called = false
          entry = Parts.plan_crop_snapshot(
            crop_id: 2,
            crop_name: "Bare",
            groups: [],
            crop_stage_count: 0,
            build_agrr_requirement: -> { called = true; {} }
          )

          refute called
          refute entry.has_growth_stages
          assert_nil entry.agrr_requirement
        end

        test "effective_cultivation_days returns stored value when present" do
          days = Parts.effective_cultivation_days(
            stored_days: 15,
            start_date: Date.new(2026, 4, 1),
            completion_date: Date.new(2026, 4, 30)
          )

          assert_equal 15, days
        end

        test "effective_cultivation_days derives inclusive days from date range when stored is nil" do
          days = Parts.effective_cultivation_days(
            stored_days: nil,
            start_date: Date.new(2026, 4, 1),
            completion_date: Date.new(2026, 4, 20)
          )

          assert_equal 20, days
        end

        test "has_growth_stages? is true when crop_stage_count is positive" do
          assert Parts.has_growth_stages?(crop_stage_count: 2)
        end

        test "has_growth_stages? is false when crop_stage_count is zero" do
          refute Parts.has_growth_stages?(crop_stage_count: 0)
        end

        test "weather_location_facts reads WeatherLocation DTO" do
          wl = Domain::WeatherData::Dtos::WeatherLocation.new(
            id: 9,
            latitude: 35.0,
            longitude: 135.0,
            elevation: 10.0,
            timezone: "Asia/Tokyo"
          )

          facts = Parts.weather_location_facts(wl)

          assert_equal({ latitude: 35.0, longitude: 135.0, elevation: 10.0, timezone: "Asia/Tokyo" }, facts)
        end
      end
    end
  end
end
