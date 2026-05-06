# frozen_string_literal: true

require "test_helper"

module Domain
  module DeletionUndo
    module Interactors
      class DeletionUndoScheduleSuccessPayloadInteractorTest < ActiveSupport::TestCase
        ScheduledUndoStub = Struct.new(
          :undo_token,
          :metadata,
          :toast_message,
          :auto_hide_after,
          :resource_type,
          :resource_id,
          keyword_init: true
        )

        test "on_failure when undo_token is blank" do
          stub = ScheduledUndoStub.new(
            undo_token: "",
            metadata: {},
            toast_message: nil,
            auto_hide_after: 5,
            resource_type: "Crop",
            resource_id: "9"
          )
          snapshot = ScheduledUndoSnapshot.from(stub)

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |dto| received = dto }

          DeletionUndoScheduleSuccessPayloadInteractor.new(output_port: output_port, logger: nil).call(snapshot)

          assert_instance_of Domain::DeletionUndo::Dtos::DeletionUndoSchedulePayloadFailureDto, received
          assert_equal :missing_undo_token, received.reason
          output_port.verify
        end

        test "on_success uses metadata resource_dom_id when present" do
          stub = ScheduledUndoStub.new(
            undo_token: "tok-a",
            metadata: {
              "undo_deadline" => "2026-05-01T00:00:00Z",
              "resource_label" => "Test crop",
              "resource_dom_id" => "custom_dom",
              "toast_message" => "from_md"
            },
            toast_message: "toast",
            auto_hide_after: 7,
            resource_type: "Crop",
            resource_id: "3"
          )
          snapshot = ScheduledUndoSnapshot.from(stub)

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |dto| received = dto }

          DeletionUndoScheduleSuccessPayloadInteractor.new(output_port: output_port, logger: nil).call(snapshot)

          assert_instance_of Domain::DeletionUndo::Dtos::DeletionUndoScheduleSuccessPayloadDto, received
          assert_equal "tok-a", received.undo_token
          assert_equal "2026-05-01T00:00:00Z", received.undo_deadline
          assert_equal "toast", received.toast_message
          assert_equal 7, received.auto_hide_after
          assert_equal "Test crop", received.resource_label
          assert_equal "custom_dom", received.resource_dom_id
          output_port.verify
        end

        test "on_success falls back to resource_type and resource_id for dom id" do
          stub = ScheduledUndoStub.new(
            undo_token: "tok-b",
            metadata: {
              "undo_deadline" => nil,
              "resource_label" => nil
            },
            toast_message: nil,
            auto_hide_after: 5,
            resource_type: "CultivationPlan",
            resource_id: "42"
          )
          snapshot = ScheduledUndoSnapshot.from(stub)

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |dto| received = dto }

          DeletionUndoScheduleSuccessPayloadInteractor.new(output_port: output_port, logger: nil).call(snapshot)

          assert_equal "cultivation_plan_42", received.resource_dom_id
          output_port.verify
        end
      end
    end
  end
end
