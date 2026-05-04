# frozen_string_literal: true

require "test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class AddCropInteractorTest < ActiveSupport::TestCase
        setup do
          @output = mock
          @flow = mock
          @plan_loader = mock
        end

        test "dispatches success from flow result" do
          @flow.expects(:full_run).with(
            plan_loader: @plan_loader,
            crop_id: "1",
            field_id: "2",
            display_range: {}
          ).returns(
            kind: :success,
            plan_crop_id: 9,
            plan_crop_display_name: "ナス"
          )
          @output.expects(:on_success).with(plan_crop_id: 9, plan_crop_display_name: "ナス")
          @output.expects(:on_not_found).never

          AddCropInteractor.new(output: @output, flow: @flow).call(
            plan_loader: @plan_loader,
            crop_id: "1",
            field_id: "2",
            display_range: {}
          )
        end

        test "dispatches not_found" do
          @flow.expects(:full_run).with(
            plan_loader: @plan_loader,
            crop_id: "1",
            field_id: nil,
            display_range: {}
          ).returns(kind: :not_found)
          @output.expects(:on_not_found).once
          @output.expects(:on_success).never

          AddCropInteractor.new(output: @output, flow: @flow).call(
            plan_loader: @plan_loader,
            crop_id: "1",
            field_id: nil,
            display_range: {}
          )
        end

        test "dispatches prediction_incomplete" do
          @flow.expects(:full_run).with(
            plan_loader: @plan_loader,
            crop_id: "1",
            field_id: nil,
            display_range: {}
          ).returns(kind: :prediction_incomplete, technical_details: "x")
          @output.expects(:on_prediction_incomplete).with(technical_details: "x")

          AddCropInteractor.new(output: @output, flow: @flow).call(
            plan_loader: @plan_loader,
            crop_id: "1",
            field_id: nil,
            display_range: {}
          )
        end

        test "dispatches adjust_failed with payload" do
          payload = { success: false, message: "adj", status: :bad_request }
          @flow.expects(:full_run).with(
            plan_loader: @plan_loader,
            crop_id: "1",
            field_id: nil,
            display_range: {}
          ).returns(kind: :adjust_failed, adjust_payload: payload)
          @output.expects(:on_adjust_failed).with(adjust_payload: payload)

          AddCropInteractor.new(output: @output, flow: @flow).call(
            plan_loader: @plan_loader,
            crop_id: "1",
            field_id: nil,
            display_range: {}
          )
        end
      end
    end
  end
end
