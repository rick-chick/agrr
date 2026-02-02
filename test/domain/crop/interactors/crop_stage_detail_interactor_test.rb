# frozen_string_literal: true

require "test_helper"

module Domain
  module Crop
    module Interactors
      class CropStageDetailInteractorTest < ActiveSupport::TestCase
        test "calls on_success with crop stage when gateway succeeds" do
          crop_stage = Domain::Crop::Entities::CropStageEntity.new(
            id: 1,
            crop_id: 1,
            name: "種まき",
            order: 1,
            created_at: Time.current,
            updated_at: Time.current
          )
          gateway = Minitest::Mock.new
          gateway.expect(:find_crop_stage_by_id, crop_stage, [1])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          interactor = CropStageDetailInteractor.new(output_port: output_port, gateway: gateway)
          input_dto = Domain::Crop::Dtos::CropStageDetailInputDto.new(crop_stage_id: 1)
          interactor.call(input_dto)

          assert_equal crop_stage, received.stage
          gateway.verify
          output_port.verify
        end

        test "calls on_failure when gateway raises" do
          gateway = Minitest::Mock.new
          gateway.expect(:find_crop_stage_by_id, nil) { raise StandardError, "crop stage not found" }

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = CropStageDetailInteractor.new(output_port: output_port, gateway: gateway)
          input_dto = Domain::Crop::Dtos::CropStageDetailInputDto.new(crop_stage_id: 1)
          interactor.call(input_dto)

          assert_instance_of Domain::Shared::Dtos::ErrorDto, received
          assert_includes received.message, "crop stage not found"
          gateway.verify
          output_port.verify
        end
      end
    end
  end
end