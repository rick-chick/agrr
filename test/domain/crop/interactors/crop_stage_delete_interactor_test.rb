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

          interactor = CropStageDeleteInteractor.new(output_port: output_port, gateway: gateway, logger: Adapters::Logger::Gateways::RailsLoggerGateway.new)
          input_dto = Domain::Crop::Dtos::CropStageDeleteInputDto.new(
            crop_id: 1,
            stage_id: 1
          )
          interactor.call(input_dto)

          assert_equal true, received.success
          gateway.verify
          output_port.verify
        end

        test "propagates StandardError when gateway raises" do
          gateway = Minitest::Mock.new
          gateway.expect(:delete_crop_stage, nil) { raise StandardError, "delete failed" }

          output_port = Minitest::Mock.new

          interactor = CropStageDeleteInteractor.new(output_port: output_port, gateway: gateway, logger: Adapters::Logger::Gateways::RailsLoggerGateway.new)
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
