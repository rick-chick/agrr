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
          @host = mock("optimization_host")
          @attach = mock
          @insert = mock
          @candidate = mock
          @adjust = mock
          @delete = mock
        end

        def interactor
          AddCropInteractor.new(
            output: @output,
            logger: @logger,
            optimization_host: @host,
            optimize_attach_gateway: @attach,
            plan_crop_insert_gateway: @insert,
            best_candidate_gateway: @candidate,
            adjust_invoke_gateway: @adjust,
            plan_crop_delete_gateway: @delete
          )
        end

        test "dispatches success from gateway result" do
          crop_entity = stub(
            id: 1,
            name: "ナス",
            variety: "v",
            area_per_unit: 1.0,
            revenue_per_area: 2.0
          )
          @attach.expects(:attach_plan!).twice.with(
            auth: @auth,
            plan_id: 9,
            optimization_host: @host
          ).returns({ kind: :success })
          @resolver.expects(:crop_for_add_crop).with("1").returns(crop_entity)
          @insert.expects(:create_plan_crop!).with(
            auth: @auth,
            plan_id: 9,
            crop_entity: crop_entity
          ).returns(
            kind: :success,
            plan_crop_id: 9,
            plan_crop_display_name: "ナス"
          )
          @candidate.expects(:find_best).with(
            auth: @auth,
            plan_id: 9,
            crop_id: 1,
            field_id: "2",
            display_range: {},
            optimization_host: @host
          ).returns(kind: :found, field_id: "2", start_date: Date.new(2026, 1, 1))
          @adjust.expects(:adjust_with_moves!).returns({ success: true })
          @delete.expects(:destroy_plan_crop!).never
          @output.expects(:on_success).with(plan_crop_id: 9, plan_crop_display_name: "ナス")
          @output.expects(:on_not_found).never

          interactor.call(
            auth: @auth,
            plan_id: 9,
            crop_id: "1",
            field_id: "2",
            display_range: {},
            crop_resolver: @resolver
          )
        end

        test "dispatches not_found" do
          @attach.expects(:attach_plan!).returns({ kind: :not_found })
          @output.expects(:on_not_found).once
          @output.expects(:on_success).never
          @insert.expects(:create_plan_crop!).never

          interactor.call(
            auth: @auth,
            plan_id: 1,
            crop_id: "1",
            field_id: nil,
            display_range: {},
            crop_resolver: @resolver
          )
        end

        test "dispatches prediction_incomplete" do
          crop_entity = stub(id: 1, name: "n", variety: "v", area_per_unit: 1.0, revenue_per_area: 1.0)
          @attach.expects(:attach_plan!).twice.returns({ kind: :success })
          @resolver.expects(:crop_for_add_crop).returns(crop_entity)
          @insert.expects(:create_plan_crop!).returns(
            kind: :success,
            plan_crop_id: 9,
            plan_crop_display_name: "n"
          )
          @candidate.expects(:find_best).returns(
            kind: :prediction_incomplete,
            technical_details: "x"
          )
          @delete.expects(:destroy_plan_crop!).with(plan_crop_id: 9)
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

        test "dispatches adjust_failed with payload" do
          crop_entity = stub(id: 1, name: "n", variety: "v", area_per_unit: 1.0, revenue_per_area: 1.0)
          payload = { success: false, message: "adj", status: :bad_request }
          @attach.expects(:attach_plan!).twice.returns({ kind: :success })
          @resolver.expects(:crop_for_add_crop).returns(crop_entity)
          @insert.expects(:create_plan_crop!).returns(
            kind: :success,
            plan_crop_id: 9,
            plan_crop_display_name: "n"
          )
          @candidate.expects(:find_best).returns(
            kind: :found,
            field_id: "2",
            start_date: Date.new(2026, 1, 1)
          )
          @adjust.expects(:adjust_with_moves!).returns(payload)
          @delete.expects(:destroy_plan_crop!).never
          @output.expects(:on_adjust_failed).with(adjust_payload: payload)

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
