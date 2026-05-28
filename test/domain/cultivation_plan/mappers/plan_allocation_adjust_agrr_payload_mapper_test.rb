# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Mappers
      class PlanAllocationAdjustAgrrPayloadMapperTest < DomainLibTestCase
        FakeLogger = Struct.new(:lines) do
          def initialize = super([])
          def info(msg) = lines << msg
        end

        def build_snapshot
          included = Dtos::AgrrAdjustFieldCultivationSourceRow.new(
            field_cultivation_id: 10,
            field_id: 1,
            crop_id: "5",
            crop_name: "Tomato",
            variety: nil,
            area: 12.0,
            start_date: Date.new(2026, 4, 1),
            completion_date: Date.new(2026, 4, 20),
            cultivation_days: 20,
            estimated_cost: 100.0,
            revenue: 200.0,
            accumulated_gdd: 1.0,
            has_growth_stages: true
          )
          field_row = Dtos::AgrrAdjustFieldSourceRow.new(
            field_id: 1,
            field_name: "North",
            field_area: 100.0,
            cultivations: [ included ]
          )
          Dtos::PlanAllocationAdjustReadSnapshot.new(
            plan_id: 99,
            field_source_rows: [ field_row ],
            plan_crop_entries: [
              Dtos::PlanAllocationAdjustReadSnapshot::PlanCropEntry.new(
                crop_id: 5,
                crop_name: "Tomato",
                groups: [ "solanaceae" ],
                has_growth_stages: true,
                agrr_requirement: { "crop" => { "crop_id" => "5" } }
              )
            ],
            plan_fields: [
              Dtos::PlanAllocationAdjustReadSnapshot::PlanFieldEntry.new(
                id: 1,
                name: "North",
                area: 100.0,
                daily_fixed_cost: 5.0
              )
            ],
            cultivation_planning_periods: [],
            planning_period_boundaries: Dtos::PlanAllocationAdjustPlanningBoundaries.new(
              planning_start_date: Date.new(2026, 1, 1),
              planning_end_date: Date.new(2026, 12, 31)
            ),
            cultivation_plan_weather_dto: Domain::WeatherData::Dtos::CultivationPlanWeather.new(
              id: 99,
              prediction_target_end_date: nil,
              calculated_planning_end_date: nil,
              predicted_weather_data: nil
            ),
            weather_prediction_targets: Domain::WeatherData::Dtos::WeatherPredictionTargets.new(
              weather_location: nil,
              farm: nil
            ),
            weather_location_facts: {},
            farm_without_weather_location: false
          )
        end

        test "to_current_allocation excludes ids via snapshot field rows" do
          snapshot = build_snapshot
          payload = PlanAllocationAdjustAgrrPayloadMapper.to_current_allocation(
            snapshot: snapshot,
            exclude_ids: [],
            logger: FakeLogger.new
          )

          schedules = payload.dig(:optimization_result, :field_schedules)
          assert_equal 1, schedules.size
          assert_equal 10, schedules.first[:allocations].first[:allocation_id]
        end
      end
    end
  end
end
