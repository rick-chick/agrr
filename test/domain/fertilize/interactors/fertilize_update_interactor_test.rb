# frozen_string_literal: true

require "test_helper"

module Domain
  module Fertilize
    module Interactors
      class FertilizeUpdateInteractorTest < ActiveSupport::TestCase
        setup do
          @user = create(:user)
          @user_id = @user.id
          @mock_gateway = mock
          @mock_output_port = mock
          @mock_translator = mock
          @interactor = FertilizeUpdateInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway,
            user_id: @user_id,
            logger: Adapters::Logger::Gateways::RailsLoggerGateway.new,
            translator: @mock_translator
          )
        end

        test "should update fertilize successfully for regular user" do
          input_dto = Domain::Fertilize::Dtos::FertilizeUpdateInputDto.new(
            fertilize_id: 1,
            name: "Updated Fertilize",
            n: 15.0
          )

          updated_fertilize_entity = mock

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:update_for_user).with(@user, 1, { name: "Updated Fertilize", n: 15.0 }).returns(updated_fertilize_entity)
          @mock_output_port.expects(:on_success).with(updated_fertilize_entity)

          @interactor.call(input_dto)
        end

        test "should raise error when non-admin user tries to change is_reference flag" do
          input_dto = Domain::Fertilize::Dtos::FertilizeUpdateInputDto.new(
            fertilize_id: 1,
            is_reference: true
          )

          current_entity = mock
          current_entity.expects(:is_reference).returns(false)

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:find_authorized_for_edit).with(@user, 1).returns(current_entity)
          @mock_translator.expects(:t).with("fertilizes.flash.reference_flag_admin_only").returns("admin only")
          @mock_output_port.expects(:on_failure).with(instance_of(Domain::Shared::Dtos::ErrorDto))

          @interactor.call(input_dto)
        end

        test "should allow admin user to change is_reference flag" do
          admin_user = create(:user, admin: true)
          admin_user_id = admin_user.id
          admin_interactor = FertilizeUpdateInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway,
            user_id: admin_user_id,
            logger: Adapters::Logger::Gateways::RailsLoggerGateway.new
          )

          input_dto = Domain::Fertilize::Dtos::FertilizeUpdateInputDto.new(
            fertilize_id: 1,
            is_reference: true
          )

          current_entity = mock
          current_entity.expects(:is_reference).returns(false)
          updated_fertilize_entity = mock

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(admin_user_id).returns(admin_user)
          @mock_gateway.expects(:find_authorized_for_edit).with(admin_user, 1).returns(current_entity)
          @mock_gateway.expects(:update_for_user).with(admin_user, 1, { is_reference: true }).returns(updated_fertilize_entity)
          @mock_output_port.expects(:on_success).with(updated_fertilize_entity)

          admin_interactor.call(input_dto)
        end

        test "should handle update failure" do
          input_dto = Domain::Fertilize::Dtos::FertilizeUpdateInputDto.new(
            fertilize_id: 1,
            name: "Updated Fertilize"
          )

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:update_for_user).raises(StandardError.new("Update failed"))
          @mock_output_port.expects(:on_failure).with(instance_of(Domain::Shared::Dtos::ErrorDto))

          @interactor.call(input_dto)
        end
      end
    end
  end
end
