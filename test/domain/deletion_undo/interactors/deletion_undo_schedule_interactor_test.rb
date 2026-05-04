# frozen_string_literal: true

require "test_helper"

module Domain
  module DeletionUndo
    module Interactors
      class DeletionUndoScheduleInteractorTest < ActiveSupport::TestCase
        setup do
          @record = Object.new
          @record.define_singleton_method(:persisted?) { true }
          @record.define_singleton_method(:validate!) { true }
        end

        test "calls on_success with entity when gateway schedules" do
          entity = Domain::DeletionUndo::Entities::DeletionUndoEntity.new(
            id: "evt-1",
            expires_at: 1.hour.from_now,
            status: "scheduled",
            metadata: { "toast_message" => "x" }
          )
          gateway = Minitest::Mock.new
          input_dto = Domain::DeletionUndo::Dtos::DeletionUndoScheduleInputDto.new(
            record: @record,
            actor: nil,
            toast_message: "removed"
          )

          gateway.expect(:schedule, entity) do |kwargs|
            assert_equal @record, kwargs[:record]
            assert_nil kwargs[:actor]
            assert_equal "removed", kwargs[:toast_message]
          end

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |e| received = e }

          DeletionUndoScheduleInteractor.new(output_port: output_port, gateway: gateway).call(input_dto)

          assert_same entity, received
          gateway.verify
          output_port.verify
        end

        test "maps DeletionUndo::Error to undo_system_error failure" do
          gateway = Minitest::Mock.new
          gateway.expect(:schedule, nil) do
            raise DeletionUndo::Error, "tok"
          end

          input_dto = Domain::DeletionUndo::Dtos::DeletionUndoScheduleInputDto.new(
            record: @record,
            actor: nil,
            toast_message: "removed"
          )

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |dto| received = dto }

          DeletionUndoScheduleInteractor.new(output_port: output_port, gateway: gateway).call(input_dto)

          assert_instance_of Domain::DeletionUndo::Dtos::DeletionUndoScheduleFailureDto, received
          assert_equal :undo_system_error, received.reason
          assert_equal "tok", received.detail_message
          gateway.verify
          output_port.verify
        end

        test "maps RecordInvalid to validation_error failure" do
          invalid = ::Farm.new

          record = Object.new
          record.define_singleton_method(:persisted?) { true }
          record.define_singleton_method(:validate!) { raise ActiveRecord::RecordInvalid.new(invalid) }

          input_dto = Domain::DeletionUndo::Dtos::DeletionUndoScheduleInputDto.new(
            record: record,
            actor: nil,
            toast_message: "removed"
          )

          gateway = Minitest::Mock.new
          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |dto| received = dto }

          DeletionUndoScheduleInteractor.new(output_port: output_port, gateway: gateway).call(input_dto)

          assert_instance_of Domain::DeletionUndo::Dtos::DeletionUndoScheduleFailureDto, received
          assert_equal :validation_error, received.reason
          assert received.detail_message.present?
        end
      end
    end
  end
end
