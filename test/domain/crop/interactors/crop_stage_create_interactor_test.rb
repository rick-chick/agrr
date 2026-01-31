# frozen_string_literal: true

require "test_helper"

module Domain
  module Crop
    module Interactors
      class CropStageCreateInteractorTest < ActiveSupport::TestCase
        setup do
          @mock_gateway = mock
          @mock_output_port = mock
          @interactor = CropStageCreateInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway
          )
        end

        test "should create crop stage successfully" do
          input_dto = Domain::Crop::Dtos::CropStageCreateInputDto.new(
            crop_id: 1,
            payload: { name: "Seedling", order: 1 }
          )
          crop_stage_entity = mock
          output_dto = mock

          @mock_gateway.expects(:create_crop_stage).with(input_dto).returns(crop_stage_entity)
          Domain::Crop::Dtos::CropStageOutputDto.expects(:new).with(stage: crop_stage_entity).returns(output_dto)
          @mock_output_port.expects(:on_success).with(output_dto)

          @interactor.call(input_dto)
        end

        test "should handle gateway error" do
          input_dto = Domain::Crop::Dtos::CropStageCreateInputDto.new(
            crop_id: 1,
            payload: { name: "Seedling", order: 1 }
          )
          error_dto = mock

          @mock_gateway.expects(:create_crop_stage).with(input_dto).raises(StandardError.new("Database error"))
          Domain::Shared::Dtos::ErrorDto.expects(:new).with("Database error").returns(error_dto)
          @mock_output_port.expects(:on_failure).with(error_dto)

          @interactor.call(input_dto)
        end
      end
    end
  end
end