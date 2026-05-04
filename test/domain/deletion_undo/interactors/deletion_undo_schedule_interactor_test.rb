# frozen_string_literal: true

require "test_helper"

module Domain
  module DeletionUndo
    module Interactors
      class DeletionUndoScheduleInteractorTest < ActiveSupport::TestCase
        test "calls on_success with entity when gateway schedules" do
          entity = Domain::DeletionUndo::Entities::DeletionUndoEntity.new(
            id: "evt-1",
            expires_at: 1.hour.from_now,
            status: "scheduled",
            metadata: { "toast_message" => "x" }
          )
          gateway = Minitest::Mock.new
          input_dto = Domain::DeletionUndo::Dtos::DeletionUndoScheduleInputDto.new(
            resource_type: "Crop",
            resource_id: 9,
            actor_id: nil,
            toast_message: "removed"
          )

          gateway.expect(:schedule, entity) do |kwargs|
            assert_equal "Crop", kwargs[:resource_type]
            assert_equal 9, kwargs[:resource_id]
            assert_nil kwargs[:actor_id]
            assert_equal "removed", kwargs[:toast_message]
            assert_equal false, kwargs[:validate_before_schedule]
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
          gateway.expect(:schedule, nil) do |kwargs|
            assert_equal "Crop", kwargs[:resource_type]
            assert_equal false, kwargs[:validate_before_schedule]
            raise DeletionUndo::Error, "tok"
          end

          input_dto = Domain::DeletionUndo::Dtos::DeletionUndoScheduleInputDto.new(
            resource_type: "Crop",
            resource_id: 1,
            actor_id: nil,
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

        test "maps shared RecordInvalid to validation_error" do
          input_dto = Domain::DeletionUndo::Dtos::DeletionUndoScheduleInputDto.new(
            resource_type: "Crop",
            resource_id: 2,
            actor_id: nil,
            toast_message: "removed",
            validate_before_schedule: true
          )

          gateway = Minitest::Mock.new
          gateway.expect(:schedule, nil) do |kwargs|
            assert_equal "Crop", kwargs[:resource_type]
            assert_equal 2, kwargs[:resource_id]
            assert_equal true, kwargs[:validate_before_schedule]
            raise Domain::Shared::Exceptions::RecordInvalid, "invalid record"
          end
          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |dto| received = dto }

          DeletionUndoScheduleInteractor.new(output_port: output_port, gateway: gateway).call(input_dto)

          assert_instance_of Domain::DeletionUndo::Dtos::DeletionUndoScheduleFailureDto, received
          assert_equal :validation_error, received.reason
          assert_equal "invalid record", received.detail_message
          gateway.verify
          output_port.verify
        end

        test "maps shared AssociationInUse to association_in_use" do
          input_dto = Domain::DeletionUndo::Dtos::DeletionUndoScheduleInputDto.new(
            resource_type: "Pest",
            resource_id: 3,
            actor_id: 7,
            toast_message: "removed"
          )

          gateway = Minitest::Mock.new
          gateway.expect(:schedule, nil) do |kwargs|
            assert_equal "Pest", kwargs[:resource_type]
            assert_equal 3, kwargs[:resource_id]
            assert_equal 7, kwargs[:actor_id]
            assert_equal false, kwargs[:validate_before_schedule]
            raise Domain::Shared::Exceptions::AssociationInUse, "in use"
          end

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |dto| received = dto }

          DeletionUndoScheduleInteractor.new(output_port: output_port, gateway: gateway).call(input_dto)

          assert_instance_of Domain::DeletionUndo::Dtos::DeletionUndoScheduleFailureDto, received
          assert_equal :association_in_use, received.reason
          assert_equal "in use", received.detail_message
          gateway.verify
          output_port.verify
        end

        test "passes validate_before_schedule false to gateway" do
          entity = Domain::DeletionUndo::Entities::DeletionUndoEntity.new(
            id: "evt-1",
            expires_at: 1.hour.from_now,
            status: "scheduled",
            metadata: {}
          )
          gateway = Minitest::Mock.new
          input_dto = Domain::DeletionUndo::Dtos::DeletionUndoScheduleInputDto.new(
            resource_type: "Farm",
            resource_id: 11,
            actor_id: nil,
            toast_message: "removed",
            validate_before_schedule: false
          )

          gateway.expect(:schedule, entity) do |kwargs|
            assert_equal "Farm", kwargs[:resource_type]
            assert_equal 11, kwargs[:resource_id]
            assert_equal false, kwargs[:validate_before_schedule]
          end

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |e| received = e }

          DeletionUndoScheduleInteractor.new(output_port: output_port, gateway: gateway).call(input_dto)

          assert_same entity, received
          gateway.verify
          output_port.verify
        end

        test "raises ArgumentError when resource_type is blank" do
          input_dto = Domain::DeletionUndo::Dtos::DeletionUndoScheduleInputDto.new(
            resource_type: "",
            resource_id: 1,
            toast_message: "x"
          )
          gateway = Minitest::Mock.new
          output_port = Minitest::Mock.new

          assert_raises(ArgumentError) do
            DeletionUndoScheduleInteractor.new(output_port: output_port, gateway: gateway).call(input_dto)
          end
        end
      end
    end
  end
end
