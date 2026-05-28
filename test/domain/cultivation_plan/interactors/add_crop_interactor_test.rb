# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class AddCropInteractorTest < DomainLibTestCase
        setup do
          @output = mock
          @add_crop_crop_resolve = mock
          @auth = Domain::CultivationPlan::Dtos::CultivationPlanRestAuth.new(mode: :private, user_id: 1)
          @logger = mock
          @logger.stubs(:error)
          @logger.stubs(:warn)
          @plan_allocation_adjust = mock
          @add_crop_adjust_result_sink = mock
          @plan_gateway = mock
          @plan_crop = mock
          @plan_allocation_candidates = mock
          @plan = Domain::CultivationPlan::Entities::CultivationPlanEntity.new(
            id: 9,
            farm_id: 1,
            user_id: 1,
            total_area: 0,
            plan_type: "private"
          )
        end

        def interactor
          AddCropInteractor.new(
            output: @output,
            logger: @logger,
            plan_allocation_adjust: @plan_allocation_adjust,
            add_crop_crop_resolve: @add_crop_crop_resolve,
            add_crop_adjust_result_sink: @add_crop_adjust_result_sink,
            plan_gateway: @plan_gateway,
            plan_crop_gateway: @plan_crop,
            plan_allocation_candidates: @plan_allocation_candidates
          )
        end

        def crop_snapshot
          Domain::Crop::Dtos::AddCropCropSnapshot.new(
            id: 1,
            name: "ナス",
            variety: "v",
            area_per_unit: 1.0,
            revenue_per_area: 2.0
          )
        end

        def plan_crop_snapshot
          Domain::CultivationPlan::Dtos::CultivationPlanCropSnapshot.new(
            id: 9,
            display_name: "ナス"
          )
        end

        def call_interactor(**overrides)
          defaults = {
            auth: @auth,
            plan_id: 9,
            crop_id: "1",
            field_id: "2",
            display_range: {},
            ui_filter_context: {}
          }
          interactor.call(**defaults.merge(overrides))
        end

        test "dispatches success" do
          crop = crop_snapshot
          @plan_gateway.expects(:find_by_id).with(9).returns(@plan)
          @add_crop_crop_resolve.expects(:call).with(crop_id: "1").returns(crop)
          @plan_crop.expects(:create).with(plan_id: 9, crop_entity: crop).returns(plan_crop_snapshot)
          @plan_allocation_candidates.expects(:call).with(
            auth: @auth,
            plan_id: 9,
            crop: crop,
            field_id: "2",
            display_range: {},
            ui_filter_context: {}
          ).returns(field_id: "2", start_date: Date.new(2026, 1, 1))
          @plan_allocation_adjust.expects(:call).with do |input|
            input.plan_id == 9 &&
              input.auth == @auth &&
              input.moves.size == 1 &&
              input.moves.first[:action] == "add"
          end
          @add_crop_adjust_result_sink.expects(:add_crop_adjust_result).returns(
            Domain::CultivationPlan::Dtos::AddCropAdjustResult.new(success: true)
          )
          @plan_crop.expects(:delete).never
          @output.expects(:on_success).with(plan_crop_id: 9, plan_crop_display_name: "ナス")

          call_interactor
        end

        test "dispatches not_found when policy denies plan" do
          denied_plan = Domain::CultivationPlan::Entities::CultivationPlanEntity.new(
            id: 1,
            farm_id: 1,
            user_id: 2,
            total_area: 0,
            plan_type: "private"
          )
          @plan_gateway.expects(:find_by_id).with(1).returns(denied_plan)
          @output.expects(:on_not_found).once
          @plan_crop.expects(:create).never
          @add_crop_crop_resolve.expects(:call).never

          call_interactor(plan_id: 1, field_id: nil)
        end

        test "dispatches crop_not_found when resolve returns nil" do
          @plan_gateway.expects(:find_by_id).returns(@plan)
          @add_crop_crop_resolve.expects(:call).with(crop_id: "1").returns(nil)
          @output.expects(:on_crop_not_found).once
          @plan_crop.expects(:create).never

          call_interactor(plan_id: 1, field_id: nil)
        end

        test "dispatches prediction_incomplete and rolls back plan crop" do
          crop = crop_snapshot
          @plan_gateway.expects(:find_by_id).returns(@plan)
          @add_crop_crop_resolve.expects(:call).returns(crop)
          @plan_crop.expects(:create).returns(plan_crop_snapshot)
          @plan_allocation_candidates.expects(:call).raises(
            Domain::WeatherData::Interactors::WeatherPredictionInteractor::WeatherDataNotFoundError.new("x")
          )
          @plan_crop.expects(:delete).with(id: 9)
          @output.expects(:on_prediction_incomplete).with(technical_details: "x")

          call_interactor(plan_id: 1, field_id: nil)
        end

        test "dispatches adjust_failed with AddCropAdjustResult" do
          crop = crop_snapshot
          adjust = Domain::CultivationPlan::Dtos::AddCropAdjustResult.new(
            success: false,
            message: "adj",
            http_status: :bad_request
          )
          @plan_gateway.expects(:find_by_id).returns(@plan)
          @add_crop_crop_resolve.expects(:call).returns(crop)
          @plan_crop.expects(:create).returns(plan_crop_snapshot)
          @plan_allocation_candidates.expects(:call).returns(field_id: "2", start_date: Date.new(2026, 1, 1))
          @plan_allocation_adjust.expects(:call)
          @add_crop_adjust_result_sink.expects(:add_crop_adjust_result).returns(adjust)
          @output.expects(:on_adjust_failed).with(adjust_result: adjust)

          call_interactor(plan_id: 1, field_id: nil)
        end
      end
    end
  end
end
