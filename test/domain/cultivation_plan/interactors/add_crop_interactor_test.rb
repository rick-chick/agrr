# frozen_string_literal: true

require "test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class AddCropInteractorTest < ActiveSupport::TestCase
        setup do
          @output = mock
          @coordinator = mock
          @resolver = mock
          @auth = Domain::CultivationPlan::Dtos::CultivationPlanRestAuth.new(mode: :private, user_id: 1)
        end

        test "dispatches success from gateway result" do
          @coordinator.expects(:run).with(
            auth: @auth,
            plan_id: 9,
            crop_id: "1",
            field_id: "2",
            display_range: {},
            crop_resolver: @resolver
          ).returns(
            kind: :success,
            plan_crop_id: 9,
            plan_crop_display_name: "ナス"
          )
          @output.expects(:on_success).with(plan_crop_id: 9, plan_crop_display_name: "ナス")
          @output.expects(:on_not_found).never

          AddCropInteractor.new(output: @output, add_crop_coordinator_gateway: @coordinator).call(
            auth: @auth,
            plan_id: 9,
            crop_id: "1",
            field_id: "2",
            display_range: {},
            crop_resolver: @resolver
          )
        end

        test "dispatches not_found" do
          @coordinator.expects(:run).returns(kind: :not_found)
          @output.expects(:on_not_found).once
          @output.expects(:on_success).never

          AddCropInteractor.new(output: @output, add_crop_coordinator_gateway: @coordinator).call(
            auth: @auth,
            plan_id: 1,
            crop_id: "1",
            field_id: nil,
            display_range: {},
            crop_resolver: @resolver
          )
        end

        test "dispatches prediction_incomplete" do
          @coordinator.expects(:run).returns(kind: :prediction_incomplete, technical_details: "x")
          @output.expects(:on_prediction_incomplete).with(technical_details: "x")

          AddCropInteractor.new(output: @output, add_crop_coordinator_gateway: @coordinator).call(
            auth: @auth,
            plan_id: 1,
            crop_id: "1",
            field_id: nil,
            display_range: {},
            crop_resolver: @resolver
          )
        end

        test "dispatches adjust_failed with payload" do
          payload = { success: false, message: "adj", status: :bad_request }
          @coordinator.expects(:run).returns(kind: :adjust_failed, adjust_payload: payload)
          @output.expects(:on_adjust_failed).with(adjust_payload: payload)

          AddCropInteractor.new(output: @output, add_crop_coordinator_gateway: @coordinator).call(
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
