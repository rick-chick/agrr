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
            gateway: @mock_gateway,
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

        test "propagates StandardError when gateway raises" do
          input_dto = Domain::Crop::Dtos::CropStageCreateInputDto.new(
            crop_id: 1,
            payload: { name: "Seedling", order: 1 }
          )

          @mock_gateway.expects(:create_crop_stage).with(input_dto).raises(StandardError.new("Database error"))

          err = assert_raises(StandardError) do
            @interactor.call(input_dto)
          end
          assert_includes err.message, "Database error"
        end
      end
    end
  end
end
