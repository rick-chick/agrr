# frozen_string_literal: true

require "test_helper"

module Domain
  module Crop
    module Interactors
      class CropStageListInteractorTest < ActiveSupport::TestCase
        test "calls on_success with crop stages when gateway succeeds" do
          crop_stages = [
            Domain::Crop::Entities::CropStageEntity.new(
              id: 1,
              crop_id: 1,
              name: "種まき",
              order: 1,
              created_at: Time.current,
              updated_at: Time.current
            )
          ]
          gateway = Minitest::Mock.new
          gateway.expect(:list_crop_stages_by_crop_id, crop_stages, [1])

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_success, nil) { |arg| received = arg }

          interactor = CropStageListInteractor.new(output_port: output_port, gateway: gateway)
          input_dto = Domain::Crop::Dtos::CropStageListInputDto.new(crop_id: 1)
          interactor.call(input_dto)

          assert_equal crop_stages, received.stages
          gateway.verify
          output_port.verify
        end

        test "calls on_failure when gateway raises" do
          gateway = Minitest::Mock.new
          gateway.expect(:list_crop_stages_by_crop_id, nil) { raise StandardError, "database error" }

          received = nil
          output_port = Minitest::Mock.new
          output_port.expect(:on_failure, nil) { |arg| received = arg }

          interactor = CropStageListInteractor.new(output_port: output_port, gateway: gateway)
          input_dto = Domain::Crop::Dtos::CropStageListInputDto.new(crop_id: 1)
          interactor.call(input_dto)

          assert_instance_of Domain::Shared::Dtos::ErrorDto, received
          assert_includes received.message, "database error"
          gateway.verify
          output_port.verify
        end
      end
    end
  end
end