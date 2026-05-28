# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      # AddCropInteractorTest は本 Interactor を mock 注入するのみで、
      # 候補ウィンドウ・天候・select_best_candidate の振る舞いは検証しない。
      class PlanAllocationCandidatesInteractorTest < DomainLibTestCase
        setup do
          @logger = mock
          @logger.stubs(:info)
          @logger.stubs(:warn)
          @logger.stubs(:error)
          @today = -> { Date.new(2026, 6, 15) }
          @plan_loader = mock
          @allocation_configs = mock
          @weather_for_candidates = mock
          @candidates_gateway = mock
          @auth = Dtos::CultivationPlanRestAuth.new(mode: :private, user_id: 1)
          @crop = stub(id: 7)
          @interactor = PlanAllocationCandidatesInteractor.new(
            logger: @logger,
            today: @today,
            plan_loader: @plan_loader,
            allocation_configs: @allocation_configs,
            weather_for_candidates: @weather_for_candidates,
            plan_allocation_candidates_gateway: @candidates_gateway
          )
        end

        def plan_with_farm(weather_location: stub)
          farm = stub(weather_location: weather_location)
          stub(
            id: 9,
            calculated_planning_start_date: Date.new(2026, 1, 1),
            calculated_planning_end_date: Date.new(2027, 6, 30),
            farm: farm
          )
        end

        def allocation_configs_hash
          {
            current_allocation: {},
            fields: [],
            crops: [],
            interaction_rules: []
          }
        end

        def call_interactor(**overrides)
          defaults = {
            auth: @auth,
            plan_id: 9,
            crop: @crop,
            field_id: "2",
            display_range: {},
            ui_filter_context: {}
          }
          @interactor.call(**defaults.merge(overrides))
        end

        test "returns nil when farm has no weather location" do
          plan = plan_with_farm(weather_location: nil)
          @plan_loader.expects(:call).with(plan_id: 9).returns(plan)
          @allocation_configs.expects(:call).with(plan).returns(allocation_configs_hash)
          @weather_for_candidates.expects(:call).never
          @candidates_gateway.expects(:candidates).never
          @logger.expects(:error).with(includes("No weather location"))

          assert_nil call_interactor
        end

        test "returns nil when weather_for_candidates returns nil" do
          wl = stub
          plan = plan_with_farm(weather_location: wl)
          @plan_loader.expects(:call).returns(plan)
          @allocation_configs.expects(:call).returns(allocation_configs_hash)
          @weather_for_candidates.expects(:call).returns(nil)
          @candidates_gateway.expects(:candidates).never

          assert_nil call_interactor
        end

        test "selects highest-profit candidate on preferred field after lower bound filter" do
          wl = stub
          plan = plan_with_farm(weather_location: wl)
          @plan_loader.expects(:call).returns(plan)
          @allocation_configs.expects(:call).returns(allocation_configs_hash)
          @weather_for_candidates.expects(:call).returns({ "data" => [] })
          @candidates_gateway.expects(:candidates).returns(
            [
              { field_id: 2, start_date: "2025-12-01", profit: 100.0 },
              { field_id: 2, start_date: "2026-02-01", profit: 50.0 },
              { field_id: 3, start_date: "2026-03-01", profit: 200.0 }
            ]
          )

          result = call_interactor(field_id: "2", display_range: { start_date: Date.new(2026, 1, 1) })

          assert_equal 2, result[:field_id]
          assert_equal "2026-02-01", result[:start_date].to_s
          assert_in_delta 50.0, result[:profit]
        end

        test "falls back to any valid field when preferred field has no valid candidates" do
          wl = stub
          plan = plan_with_farm(weather_location: wl)
          @plan_loader.expects(:call).returns(plan)
          @allocation_configs.expects(:call).returns(allocation_configs_hash)
          @weather_for_candidates.expects(:call).returns({ "data" => [] })
          @candidates_gateway.expects(:candidates).returns(
            [
              { field_id: 3, start_date: "2026-04-01", profit: 80.0 },
              { field_id: 3, start_date: "2026-05-01", profit: 120.0 }
            ]
          )

          result = call_interactor(field_id: "2")

          assert_equal 3, result[:field_id]
          assert_in_delta 120.0, result[:profit]
        end

        test "returns nil when gateway raises AllocationNoCandidatesError" do
          wl = stub
          plan = plan_with_farm(weather_location: wl)
          @plan_loader.expects(:call).returns(plan)
          @allocation_configs.expects(:call).returns(allocation_configs_hash)
          @weather_for_candidates.expects(:call).returns({ "data" => [] })
          @candidates_gateway.expects(:candidates).raises(
            Domain::CultivationPlan::Errors::AllocationNoCandidatesError.new("none")
          )
          @logger.expects(:info).with(includes("No allocation candidates"))

          assert_nil call_interactor
        end
      end
    end
  end
end
