# frozen_string_literal: true

require "test_helper"

module Domain
  module Fertilize
    module Interactors
      class FertilizeCreateInteractorTest < ActiveSupport::TestCase
        setup do
          @user = create(:user)
          @user_id = @user.id
          @mock_gateway = mock
          @mock_output_port = mock
          @mock_translator = mock
          @interactor = FertilizeCreateInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway,
            user_id: @user_id,
            logger: Adapters::Logger::Gateways::RailsLoggerGateway.new,
            translator: @mock_translator,
            user_lookup: Adapters::Shared::Gateways::UserActiveRecordGateway.new
          )
        end

        test "should create fertilize successfully for regular user" do
          input_dto = Domain::Fertilize::Dtos::FertilizeCreateInputDto.new(
            name: "Test Fertilize",
            n: 10.0,
            p: 5.0,
            k: 3.0,
            region: "Kyoto"
          )

          fertilize_entity = mock

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:create_for_user).with(@user, {
            name: "Test Fertilize",
            n: 10.0,
            p: 5.0,
            k: 3.0,
            description: nil,
            package_size: nil,
            region: "Kyoto",
            is_reference: false
          }).returns(fertilize_entity)
          @mock_output_port.expects(:on_success).with(fertilize_entity)

          @interactor.call(input_dto)
        end

        test "should raise error when non-admin user tries to create reference fertilize" do
          input_dto = Domain::Fertilize::Dtos::FertilizeCreateInputDto.new(
            name: "Test Reference Fertilize",
            is_reference: true
          )

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).returns(@user)
          @mock_translator.expects(:t).with("fertilizes.flash.reference_only_admin").returns("admin only")
          @mock_output_port.expects(:on_failure).with(instance_of(Domain::Shared::Dtos::ErrorDto))

          @interactor.call(input_dto)
        end

        test "should create reference fertilize for admin user" do
          admin_user = create(:user, admin: true)
          admin_user_id = admin_user.id
          admin_interactor = FertilizeCreateInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway,
            user_id: admin_user_id,
            logger: Adapters::Logger::Gateways::RailsLoggerGateway.new,
            translator: @mock_translator,
            user_lookup: Adapters::Shared::Gateways::UserActiveRecordGateway.new
          )

          input_dto = Domain::Fertilize::Dtos::FertilizeCreateInputDto.new(
            name: "Test Reference Fertilize",
            is_reference: true
          )

          fertilize_entity = mock

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(admin_user_id).returns(admin_user)
          @mock_gateway.expects(:create_for_user).with(admin_user, {
            name: "Test Reference Fertilize",
            n: nil,
            p: nil,
            k: nil,
            description: nil,
            package_size: nil,
            region: nil,
            is_reference: true
          }).returns(fertilize_entity)
          @mock_output_port.expects(:on_success).with(fertilize_entity)

          admin_interactor.call(input_dto)
        end

        test "should call on_failure with policy exception when gateway denies" do
          input_dto = Domain::Fertilize::Dtos::FertilizeCreateInputDto.new(name: "X")

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:create_for_user).raises(Domain::Shared::Policies::PolicyPermissionDenied)

          received = nil
          @mock_output_port
            .expects(:on_failure)
            .with(instance_of(Domain::Shared::Policies::PolicyPermissionDenied)) { |e| received = e }

          @interactor.call(input_dto)

          assert_instance_of Domain::Shared::Policies::PolicyPermissionDenied, received
        end

        test "should handle save failure" do
          input_dto = Domain::Fertilize::Dtos::FertilizeCreateInputDto.new(
            name: "Test Fertilize"
          )

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:create_for_user).raises(StandardError.new("Name can't be blank"))
          @mock_output_port.expects(:on_failure).with(instance_of(Domain::Shared::Dtos::ErrorDto))

          @interactor.call(input_dto)
        end

        test "should call on_failure when user lookup raises RecordNotFound" do
          input_dto = Domain::Fertilize::Dtos::FertilizeCreateInputDto.new(name: "X")
          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).raises(
            Domain::Shared::Exceptions::RecordNotFound, "User not found"
          )
          @mock_output_port.expects(:on_failure).with(instance_of(Domain::Shared::Dtos::ErrorDto))

          @interactor.call(input_dto)
        end
      end
    end
  end
end
