# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Interactors
      class CropStageCreateInteractorTest < DomainLibTestCase
        setup do
          @mock_gateway = mock
          @mock_output_port = mock
          @interactor = CropStageCreateInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway,
          )
        end

        test "should create crop stage successfully" do
          input_dto = Domain::Crop::Dtos::CropStageCreateInput.new(
            crop_id: 1,
            payload: { name: "Seedling", order: 1 }
          )
          crop_stage_entity = mock
          output_dto = mock

          @mock_gateway.expects(:create_crop_stage).with(input_dto).returns(crop_stage_entity)
          Domain::Crop::Dtos::CropStageOutput.expects(:new).with(stage: crop_stage_entity).returns(output_dto)
          @mock_output_port.expects(:on_success).with(output_dto)

          @interactor.call(input_dto)
        end

        test "calls on_failure with Error when gateway raises RecordInvalid" do
          input_dto = Domain::Crop::Dtos::CropStageCreateInput.new(
            crop_id: 1,
            payload: { name: "", order: 1 }
          )

          @mock_gateway.expects(:create_crop_stage).with(input_dto).raises(
            Domain::Shared::Exceptions::RecordInvalid.new("Name can't be blank")
          )

          received_failure = nil
          output_port = Object.new
          output_port.define_singleton_method(:on_success) { |_| raise "must not call on_success" }
          output_port.define_singleton_method(:on_failure) { |dto| received_failure = dto }

          interactor = CropStageCreateInteractor.new(output_port: output_port, gateway: @mock_gateway)
          interactor.call(input_dto)

          assert_instance_of Domain::Shared::Dtos::Error, received_failure
          assert_equal "Name can't be blank", received_failure.message
        end

        test "propagates StandardError when gateway raises" do
          input_dto = Domain::Crop::Dtos::CropStageCreateInput.new(
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
