# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Mappers
      class PlanAllocationAdjustReadSnapshotPartsTest < DomainLibTestCase
        Parts = PlanAllocationAdjustReadSnapshotParts
        Snapshot = Dtos::PlanAllocationAdjustReadSnapshot

        test "build_field_source_rows normalizes optimize-style optimization_result keys" do
          plan_fields = [
            Snapshot::PlanFieldEntry.new(id: 2, name: "North", area: 100.0, daily_fixed_cost: 5.0)
          ]
          field_cultivation = Struct.new(
            :field_cultivation_id,
            :field_id,
            :crop_id,
            :crop_name,
            :variety,
            :area,
            :start_date,
            :completion_date,
            :cultivation_days,
            :estimated_cost,
            :optimization_result,
            :has_growth_stages,
            keyword_init: true
          ).new(
            field_cultivation_id: 10,
            field_id: 2,
            crop_id: 5,
            crop_name: "Tomato",
            variety: nil,
            area: 12.0,
            start_date: Date.new(2026, 4, 1),
            completion_date: Date.new(2026, 4, 20),
            cultivation_days: 20,
            estimated_cost: 100.0,
            optimization_result: {
              "expected_revenue" => 200.0,
              "profit" => 100.0,
              "raw" => { "total_gdd" => 42.0 }
            },
            has_growth_stages: true
          )

          rows = Parts.build_field_source_rows(
            plan_fields: plan_fields,
            field_cultivations: [ field_cultivation ]
          )
          source = rows.first.cultivations.first

          assert_in_delta 200.0, source.revenue, 0.001
          assert_in_delta 42.0, source.accumulated_gdd, 0.001
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
