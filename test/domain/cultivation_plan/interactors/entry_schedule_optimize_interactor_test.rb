# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class EntryScheduleOptimizeInteractorTest < DomainLibTestCase
        CropStub = Struct.new(:id, :name, :variety, keyword_init: true)

        setup do
          @rows = (1..3).map do |d|
            {
              "time" => "2026-05-#{d.to_s.rjust(2, '0')}",
              "temperature_2m_min" => 8.0,
              "temperature_2m_max" => 22.0,
              "temperature_2m_mean" => 15.0
            }
          end
          @crop = CropStub.new(id: 1, name: "トマト", variety: "general")
          @fixed_today = Date.new(2026, 6, 15)
          @clock = Struct.new(:today).new(@fixed_today)
        end

        test "returns disabled result when agrr is not enabled" do
          interactor = EntryScheduleOptimizeInteractor.new(
            crop: @crop,
            weather_payload: { "latitude" => 35.0, "longitude" => 139.0, "data" => @rows },
            crop_gateway: mock,
            crop_agrr_requirement_builder: mock,
            entry_schedule_optimization_gateway: mock,
            clock: @clock,
            agrr_enabled: false
          )

          result = interactor.call

          assert_not result.eligible
          assert_equal "disabled", result.reason_parts[:error_key]
        end

        test "evaluation_range intersects last-june through next-june with weather dates" do
          nested = {
            "data" => {
              "data" => @rows,
              "latitude" => 35.0,
              "longitude" => 139.0
            }
          }
          gateway = mock
          gateway.expects(:optimize_period).never
          crop_gateway = mock
          crop_gateway.expects(:entry_schedule_ordered_stage_rows).never
          builder = mock
          builder.expects(:build_from).never

          interactor = EntryScheduleOptimizeInteractor.new(
            crop: @crop,
            weather_payload: nested,
            crop_gateway: crop_gateway,
            crop_agrr_requirement_builder: builder,
            entry_schedule_optimization_gateway: gateway,
            clock: @clock,
            agrr_enabled: true
          )
          range = interactor.send(:evaluation_range)

          assert_equal Date.new(2026, 5, 1), range[0]
          assert_equal Date.new(2026, 5, 3), range[1]
        end

        test "scales crop requirement via EntryScheduleStageGddScaler before optimize_period" do
          weather = { "latitude" => 35.0, "longitude" => 139.0, "data" => @rows }
          req = {
            "stage_requirements" => [
              { "thermal" => { "required_gdd" => 800.0 } },
              { "thermal" => { "required_gdd" => 800.0 } }
            ]
          }
          builder = mock
          builder.expects(:build_from).with(@crop).returns(req)

          crop_gateway = mock
          crop_gateway.expects(:entry_schedule_ordered_stage_rows).with(crop_id: 1).returns([])

          optimization_gateway = mock
          optimization_gateway.expects(:optimize_period).with do |**kwargs|
            total = kwargs[:crop_requirement]["stage_requirements"].sum { |s| s["thermal"]["required_gdd"].to_f }
            total <= 2000.01
          end.returns(
            start_date: Date.new(2026, 5, 1),
            completion_date: Date.new(2026, 5, 10),
            days: 10,
            gdd: 100.0,
            cost: 1.0
          )

          result = EntryScheduleOptimizeInteractor.new(
            crop: @crop,
            weather_payload: weather,
            crop_gateway: crop_gateway,
            crop_agrr_requirement_builder: builder,
            entry_schedule_optimization_gateway: optimization_gateway,
            clock: @clock
          ).call

          assert result.eligible
          assert_equal "agrr_optimize_period", result.reason_parts[:source]
        end

        test "maps EntryScheduleOptimizationError to failed result" do
          weather = { "latitude" => 35.0, "longitude" => 139.0, "data" => @rows }
          builder = mock
          builder.expects(:build_from).returns("stage_requirements" => [])

          optimization_gateway = mock
          optimization_gateway.expects(:optimize_period).raises(
            Errors::EntryScheduleOptimizationError.new(:daemon_unavailable, "down")
          )

          result = EntryScheduleOptimizeInteractor.new(
            crop: @crop,
            weather_payload: weather,
            crop_gateway: mock,
            crop_agrr_requirement_builder: builder,
            entry_schedule_optimization_gateway: optimization_gateway,
            clock: @clock
          ).call

          assert_not result.eligible
          assert_equal "daemon_unavailable", result.reason_parts[:error_key]
        end
      end
    end
  end
end
