# frozen_string_literal: true

require "test_helper"

module Domain
  module Crop
    module Interactors
      class CropStageDeleteInteractorTest < ActiveSupport::TestCase
        test "calls on_success with delete result when gateway succeeds" do
          gateway = Minitest::Mock.new
          gateway.expect(:delete_crop_stage, nil, [ 1 ])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          interactor = CropStageDeleteInteractor.new(output_port: output_port, gateway: gateway)
          input_dto = Domain::Crop::Dtos::CropStageDeleteInputDto.new(
            crop_id: 1,
            stage_id: 1
          )
          interactor.call(input_dto)

          assert_equal true, received.success
          gateway.verify
          output_port.verify
        end

        test "calls on_failure with ErrorDto when gateway raises RecordInvalid" do
          gateway = Minitest::Mock.new
          gateway.expect(:delete_crop_stage, nil) do |stage_id|
            assert_equal 9, stage_id
            raise Domain::Shared::Exceptions::RecordInvalid.new("cannot delete")
          end

          received_failure = nil
          output_port = Object.new
          output_port.define_singleton_method(:on_success) { |_| raise "must not call on_success" }
          output_port.define_singleton_method(:on_failure) { |dto| received_failure = dto }

          interactor = CropStageDeleteInteractor.new(output_port: output_port, gateway: gateway)
          input_dto = Domain::Crop::Dtos::CropStageDeleteInputDto.new(crop_id: 1, stage_id: 9)
          interactor.call(input_dto)

          assert_instance_of Domain::Shared::Dtos::ErrorDto, received_failure
          assert_equal "cannot delete", received_failure.message
          gateway.verify
        end

        test "propagates StandardError when gateway raises" do
          gateway = Minitest::Mock.new
          gateway.expect(:delete_crop_stage, nil) { raise StandardError, "delete failed" }

          output_port = Minitest::Mock.new

          interactor = CropStageDeleteInteractor.new(output_port: output_port, gateway: gateway)
          input_dto = Domain::Crop::Dtos::CropStageDeleteInputDto.new(
            crop_id: 1,
            stage_id: 1
          )
          err = assert_raises(StandardError) do
            interactor.call(input_dto)
          end
          assert_includes err.message, "delete failed"
          gateway.verify
        end
      end
    end
  end
end
