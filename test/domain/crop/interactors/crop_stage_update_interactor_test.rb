# frozen_string_literal: true

require "test_helper"

module Domain
  module Crop
    module Interactors
      class CropStageUpdateInteractorTest < ActiveSupport::TestCase
        test "calls on_success with updated crop stage when gateway succeeds" do
          updated_crop_stage = Domain::Crop::Entities::CropStageEntity.new(
            id: 1,
            crop_id: 1,
            name: "発芽",
            order: 2,
            created_at: Time.current,
            updated_at: Time.current
          )
          gateway = Minitest::Mock.new
          payload = { name: "発芽", order: 2 }
          gateway.expect(:update_crop_stage, updated_crop_stage, [1, payload])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          interactor = CropStageUpdateInteractor.new(output_port: output_port, gateway: gateway)
          input_dto = Domain::Crop::Dtos::CropStageUpdateInputDto.new(
            crop_id: 1,
            stage_id: 1,
            payload: payload
          )
          interactor.call(input_dto)

          assert_equal updated_crop_stage, received.stage
          gateway.verify
          output_port.verify
        end

        test "calls on_failure when gateway raises" do
          gateway = Minitest::Mock.new
          payload = { name: "発芽", order: 2 }
          gateway.expect(:update_crop_stage, nil) { raise StandardError, "update failed" }

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = CropStageUpdateInteractor.new(output_port: output_port, gateway: gateway)
          input_dto = Domain::Crop::Dtos::CropStageUpdateInputDto.new(
            crop_id: 1,
            stage_id: 1,
            payload: payload
          )
          interactor.call(input_dto)

          assert_instance_of Domain::Shared::Dtos::ErrorDto, received
          assert_includes received.message, "update failed"
          gateway.verify
          output_port.verify
        end
      end
    end
  end
end