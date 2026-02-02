# frozen_string_literal: true

require "test_helper"

module Domain
  module Crop
    module Interactors
      class CropStageDeleteInteractorTest < ActiveSupport::TestCase
        test "calls on_success with delete result when gateway succeeds" do
          gateway = Minitest::Mock.new
          gateway.expect(:delete_crop_stage, nil, [1])

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

        test "calls on_failure when gateway raises" do
          gateway = Minitest::Mock.new
          gateway.expect(:delete_crop_stage, nil) { raise StandardError, "delete failed" }

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = CropStageDeleteInteractor.new(output_port: output_port, gateway: gateway)
          input_dto = Domain::Crop::Dtos::CropStageDeleteInputDto.new(
            crop_id: 1,
            stage_id: 1
          )
          interactor.call(input_dto)

          assert_instance_of Domain::Shared::Dtos::ErrorDto, received
          assert_includes received.message, "delete failed"
          gateway.verify
          output_port.verify
        end
      end
    end
  end
end