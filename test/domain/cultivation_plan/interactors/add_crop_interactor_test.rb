# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class AddCropInteractorTest < DomainLibTestCase
        setup do
          @output = mock
          @resolver = mock
          @auth = Domain::CultivationPlan::Dtos::CultivationPlanRestAuth.new(mode: :private, user_id: 1)
          @logger = mock
          @logger.stubs(:error)
          @logger.stubs(:warn)
          @host = mock
          @host.stubs(:attach_plan_for_candidates!)
          @plan_crop = mock
          @find_best = mock
        end

        def interactor
          AddCropInteractor.new(
            output: @output,
            logger: @logger,
            optimization_host: @host,
            plan_crop_gateway: @plan_crop,
            find_best_candidate: @find_best
          )
        end

        def crop_entity
          stub(
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

        test "dispatches success" do
          crop = crop_entity
          @host.expects(:attach_plan_for_candidates!).twice.with(auth: @auth, plan_id: 9)
          @resolver.expects(:crop_for_add_crop).with("1").returns(crop)
          @plan_crop.expects(:create).with(auth: @auth, plan_id: 9, crop_entity: crop).returns(plan_crop_snapshot)
          @find_best.expects(:call).with(
            auth: @auth,
            plan_id: 9,
            crop: crop,
            field_id: "2",
            display_range: {},
            ui_filter_context: {}
          ).returns(field_id: "2", start_date: Date.new(2026, 1, 1))
          @host.expects(:adjust_with_moves!).returns(
            Domain::CultivationPlan::Dtos::AddCropAdjustResult.new(success: true)
          )
          @plan_crop.expects(:delete).never
          @output.expects(:on_success).with(plan_crop_id: 9, plan_crop_display_name: "ナス")

          interactor.call(
            auth: @auth,
            plan_id: 9,
            crop_id: "1",
            field_id: "2",
            display_range: {},
            crop_resolver: @resolver
          )
        end

        test "dispatches not_found on attach" do
          @host.expects(:attach_plan_for_candidates!).raises(Domain::Shared::Exceptions::RecordNotFound)
          @output.expects(:on_not_found).once
          @plan_crop.expects(:create).never

          interactor.call(
            auth: @auth,
            plan_id: 1,
            crop_id: "1",
            field_id: nil,
            display_range: {},
            crop_resolver: @resolver
          )
        end

        test "dispatches prediction_incomplete and rolls back plan crop" do
          crop = crop_entity
          @resolver.expects(:crop_for_add_crop).returns(crop)
          @plan_crop.expects(:create).returns(plan_crop_snapshot)
          @find_best.expects(:call).raises(
            Domain::WeatherData::Interactors::WeatherPredictionInteractor::WeatherDataNotFoundError.new("x")
          )
          @plan_crop.expects(:delete).with(id: 9)
          @output.expects(:on_prediction_incomplete).with(technical_details: "x")

          interactor.call(
            auth: @auth,
            plan_id: 1,
            crop_id: "1",
            field_id: nil,
            display_range: {},
            crop_resolver: @resolver
          )
        end

        test "dispatches adjust_failed with legacy payload" do
          crop = crop_entity
          adjust = Domain::CultivationPlan::Dtos::AddCropAdjustResult.new(
            success: false,
            message: "adj",
            http_status: :bad_request
          )
          @resolver.expects(:crop_for_add_crop).returns(crop)
          @plan_crop.expects(:create).returns(plan_crop_snapshot)
          @find_best.expects(:call).returns(field_id: "2", start_date: Date.new(2026, 1, 1))
          @host.expects(:adjust_with_moves!).returns(adjust)
          @output.expects(:on_adjust_failed).with(
            adjust_payload: { success: false, message: "adj", status: :bad_request }
          )

          interactor.call(
            auth: @auth,
            plan_id: 1,
            crop_id: "1",
            field_id: nil,
            display_range: {},
            crop_resolver: @resolver
          )
        end
      end
    end
  end
end
