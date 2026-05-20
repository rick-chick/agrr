# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Interactors
      class CropStageUpdateInteractorTest < DomainLibTestCase
        test "calls on_success with updated crop stage when gateway succeeds" do
          updated_crop_stage = Domain::Crop::Entities::CropStageEntity.new(
            id: 1,
            crop_id: 1,
            name: "発芽",
            order: 2,
            created_at: Time.utc(2026, 1, 1),
            updated_at: Time.utc(2026, 1, 1)
          )
          gateway = Minitest::Mock.new
          payload = { name: "発芽", order: 2 }
          input_dto = Domain::Crop::Dtos::CropStageUpdateInput.new(
            crop_id: 1,
            stage_id: 1,
            payload: payload
          )
          gateway.expect(:update_crop_stage, updated_crop_stage, [ 1, input_dto ])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          interactor = CropStageUpdateInteractor.new(output_port: output_port, gateway: gateway)
          interactor.call(input_dto)

          assert_equal updated_crop_stage, received.stage
          gateway.verify
          output_port.verify
        end

        test "calls on_failure with Error when gateway raises RecordInvalid" do
          gateway = Minitest::Mock.new
          payload = { name: "", order: 2 }
          input_dto = Domain::Crop::Dtos::CropStageUpdateInput.new(
            crop_id: 1,
            stage_id: 1,
            payload: payload
          )
          gateway.expect(:update_crop_stage, nil) do |id, dto|
            assert_equal 1, id
            assert_equal input_dto, dto
            raise Domain::Shared::Exceptions::RecordInvalid.new("Name can't be blank")
          end

          received_failure = nil
          output_port = Object.new
          output_port.define_singleton_method(:on_success) { |_| raise "must not call on_success" }
          output_port.define_singleton_method(:on_failure) { |dto| received_failure = dto }

          interactor = CropStageUpdateInteractor.new(output_port: output_port, gateway: gateway)
          interactor.call(input_dto)

          assert_instance_of Domain::Shared::Dtos::Error, received_failure
          assert_equal "Name can't be blank", received_failure.message
          gateway.verify
        end

        test "propagates StandardError when gateway raises" do
          gateway = Minitest::Mock.new
          payload = { name: "発芽", order: 2 }
          input_dto = Domain::Crop::Dtos::CropStageUpdateInput.new(
            crop_id: 1,
            stage_id: 1,
            payload: payload
          )
          gateway.expect(:update_crop_stage, nil) do |id, dto|
            assert_equal 1, id
            assert_equal input_dto, dto
            raise StandardError, "update failed"
          end

          output_port = Minitest::Mock.new

          interactor = CropStageUpdateInteractor.new(output_port: output_port, gateway: gateway)
          err = assert_raises(StandardError) do
            interactor.call(input_dto)
          end
          assert_includes err.message, "update failed"
          gateway.verify
        end
      end
    end
  end
end
