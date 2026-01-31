# frozen_string_literal: true

require "test_helper"

module Domain
  module Crop
    module Interactors
      class TemperatureRequirementUpdateInteractorTest < ActiveSupport::TestCase
        setup do
          @mock_gateway = mock
          @mock_output_port = mock
          @interactor = TemperatureRequirementUpdateInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway
          )
        end

        test "should create temperature requirement when it does not exist" do
          input_dto = Domain::Crop::Dtos::TemperatureRequirementUpdateInputDto.new(
            crop_id: 1,
            stage_id: 1,
            payload: { base_temperature: 10.0, optimal_min: 15.0, optimal_max: 25.0 }
          )
          requirement_entity = mock
          output_dto = mock

          @mock_gateway.expects(:find_temperature_requirement).with(1).returns(nil)
          @mock_gateway.expects(:create_temperature_requirement).with(1, input_dto).returns(requirement_entity)
          Domain::Crop::Dtos::TemperatureRequirementOutputDto.expects(:new).with(requirement: requirement_entity).returns(output_dto)
          @mock_output_port.expects(:on_success).with(output_dto)

          @interactor.call(input_dto)
        end

        test "should update temperature requirement when it exists" do
          input_dto = Domain::Crop::Dtos::TemperatureRequirementUpdateInputDto.new(
            crop_id: 1,
            stage_id: 1,
            payload: { base_temperature: 10.0, optimal_min: 15.0, optimal_max: 25.0 }
          )
          existing_requirement = mock
          updated_requirement = mock
          output_dto = mock

          @mock_gateway.expects(:find_temperature_requirement).with(1).returns(existing_requirement)
          @mock_gateway.expects(:update_temperature_requirement).with(1, input_dto).returns(updated_requirement)
          Domain::Crop::Dtos::TemperatureRequirementOutputDto.expects(:new).with(requirement: updated_requirement).returns(output_dto)
          @mock_output_port.expects(:on_success).with(output_dto)

          @interactor.call(input_dto)
        end

        test "should handle gateway error" do
          input_dto = Domain::Crop::Dtos::TemperatureRequirementUpdateInputDto.new(
            crop_id: 1,
            stage_id: 1,
            payload: { base_temperature: 10.0 }
          )
          error_dto = mock

          @mock_gateway.expects(:find_temperature_requirement).with(1).raises(StandardError.new("Database error"))
          Domain::Shared::Dtos::ErrorDto.expects(:new).with("Database error").returns(error_dto)
          @mock_output_port.expects(:on_failure).with(error_dto)

          @interactor.call(input_dto)
        end
      end
    end
  end
end