# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Interactors
      class MastersTemperatureRequirementShowInteractorTest < DomainLibTestCase
        setup do
          @mock_gateway = mock
          @mock_requirement_gateway = mock
          @mock_output_port = mock
          @interactor = MastersTemperatureRequirementShowInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway,
            requirement_gateway: @mock_requirement_gateway
          )
        end

        test "renders show success when requirement exists" do
          dto = Domain::Crop::Dtos::CropStageDetailInput.new(crop_stage_id: 9)
          entity = mock

          @mock_requirement_gateway.expects(:find_by_crop_stage_id).with(9).returns(entity)
          @mock_output_port.expects(:on_show_success).with(entity)

          @interactor.call(dto)
        end

        test "renders not found when requirement missing" do
          dto = Domain::Crop::Dtos::CropStageDetailInput.new(crop_stage_id: 9)

          @mock_requirement_gateway.expects(:find_by_crop_stage_id).with(9).returns(nil)
          @mock_output_port.expects(:on_not_found)

          @interactor.call(dto)
        end
      end

      class MastersTemperatureRequirementCreateInteractorTest < DomainLibTestCase
        setup do
          @mock_gateway = mock
          @mock_requirement_gateway = mock
          @mock_output_port = mock
          @interactor = MastersTemperatureRequirementCreateInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway,
            requirement_gateway: @mock_requirement_gateway
          )
        end

        test "creates when absent and reports success" do
          dto = Domain::Crop::Dtos::TemperatureRequirementUpdateInput.new(
            crop_id: 1,
            stage_id: 2,
            payload: { base_temperature: 1.0 }
          )
          created = mock

          @mock_requirement_gateway.expects(:find_by_crop_stage_id).with(2).returns(nil)
          @mock_gateway.expects(:create_temperature_requirement).with(2, dto).returns(created)
          @mock_output_port.expects(:on_create_success).with(created)

          @interactor.call(dto)
        end

        test "reports already exists when requirement present" do
          dto = Domain::Crop::Dtos::TemperatureRequirementUpdateInput.new(
            crop_id: 1,
            stage_id: 2,
            payload: { base_temperature: 1.0 }
          )

          @mock_requirement_gateway.expects(:find_by_crop_stage_id).with(2).returns(mock)
          @mock_gateway.expects(:create_temperature_requirement).never
          @mock_output_port.expects(:on_already_exists)

          @interactor.call(dto)
        end

        test "reports validation errors on RecordInvalid" do
          dto = Domain::Crop::Dtos::TemperatureRequirementUpdateInput.new(
            crop_id: 1,
            stage_id: 2,
            payload: { base_temperature: "bad" }
          )

          @mock_requirement_gateway.expects(:find_by_crop_stage_id).with(2).returns(nil)
          err = Domain::Shared::Exceptions::RecordInvalid.new("x", errors: [ "must be numeric" ])
          @mock_gateway.expects(:create_temperature_requirement).raises(err)
          @mock_output_port.expects(:on_validation_errors).with([ "must be numeric" ])

          @interactor.call(dto)
        end
      end

      class MastersTemperatureRequirementUpdateInteractorTest < DomainLibTestCase
        setup do
          @mock_gateway = mock
          @mock_requirement_gateway = mock
          @mock_output_port = mock
          @interactor = MastersTemperatureRequirementUpdateInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway,
            requirement_gateway: @mock_requirement_gateway
          )
        end

        test "updates when present" do
          dto = Domain::Crop::Dtos::TemperatureRequirementUpdateInput.new(
            crop_id: 1,
            stage_id: 2,
            payload: { base_temperature: 3.0 }
          )
          existing = mock
          updated = mock

          @mock_requirement_gateway.expects(:find_by_crop_stage_id).with(2).returns(existing)
          @mock_gateway.expects(:update_temperature_requirement).with(2, dto).returns(updated)
          @mock_output_port.expects(:on_update_success).with(updated)

          @interactor.call(dto)
        end

        test "not found when missing before update" do
          dto = Domain::Crop::Dtos::TemperatureRequirementUpdateInput.new(
            crop_id: 1,
            stage_id: 2,
            payload: {}
          )

          @mock_requirement_gateway.expects(:find_by_crop_stage_id).with(2).returns(nil)
          @mock_gateway.expects(:update_temperature_requirement).never
          @mock_output_port.expects(:on_not_found)

          @interactor.call(dto)
        end
      end

      class MastersTemperatureRequirementDestroyInteractorTest < DomainLibTestCase
        setup do
          @mock_gateway = mock
          @mock_output_port = mock
          @interactor = MastersTemperatureRequirementDestroyInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway
          )
        end

        test "destroys and reports success" do
          dto = Domain::Crop::Dtos::CropStageDetailInput.new(crop_stage_id: 5)

          @mock_gateway.expects(:delete_temperature_requirement).with(5)
          @mock_output_port.expects(:on_destroy_success)

          @interactor.call(dto)
        end

        test "not found when gateway raises RecordNotFound" do
          dto = Domain::Crop::Dtos::CropStageDetailInput.new(crop_stage_id: 5)

          @mock_gateway.expects(:delete_temperature_requirement).raises(Domain::Shared::Exceptions::RecordNotFound.new("TemperatureRequirement not found"))
          @mock_output_port.expects(:on_not_found)

          @interactor.call(dto)
        end
      end
    end
  end
end
