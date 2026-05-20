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
            translator: @mock_translator,
            user_lookup: Adapters::Shared::Gateways::UserActiveRecordGateway.new
          )
        end

        test "should create fertilize successfully for regular user" do
          input_dto = Domain::Fertilize::Dtos::FertilizeCreateInput.new(
            name: "Test Fertilize",
            n: 10.0,
            p: 5.0,
            k: 3.0,
            region: "Kyoto"
          )

          fertilize_entity = mock

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:create_for_user).with(@user, instance_of(Hash)).returns(fertilize_entity)
          @mock_output_port.expects(:on_success).with(fertilize_entity)

          @interactor.call(input_dto)
        end

        test "should raise error when non-admin user tries to create reference fertilize" do
          input_dto = Domain::Fertilize::Dtos::FertilizeCreateInput.new(
            name: "Test Reference Fertilize",
            is_reference: true
          )

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).returns(@user)
          @mock_translator.expects(:t).with("fertilizes.flash.reference_only_admin").returns("admin only")
          @mock_gateway.expects(:build_after_create_failure_fertilize_for_master_form!).with(user: @user, attributes: instance_of(Hash)).returns(mock)
          @mock_output_port.expects(:on_failure).with(instance_of(Domain::Fertilize::Dtos::FertilizeCreateFailure))

          @interactor.call(input_dto)
        end

        test "should create reference fertilize for admin user" do
          admin_user = create(:user, admin: true)
          admin_user_id = admin_user.id
          admin_interactor = FertilizeCreateInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway,
            user_id: admin_user_id,
            translator: @mock_translator,
            user_lookup: Adapters::Shared::Gateways::UserActiveRecordGateway.new
          )

          input_dto = Domain::Fertilize::Dtos::FertilizeCreateInput.new(
            name: "Test Reference Fertilize",
            is_reference: true
          )

          fertilize_entity = mock

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(admin_user_id).returns(admin_user)
          @mock_gateway.expects(:create_for_user).with(admin_user, instance_of(Hash)).returns(fertilize_entity)
          @mock_output_port.expects(:on_success).with(fertilize_entity)

          admin_interactor.call(input_dto)
        end

        test "should call on_failure with policy exception when gateway denies" do
          input_dto = Domain::Fertilize::Dtos::FertilizeCreateInput.new(name: "X")

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
          input_dto = Domain::Fertilize::Dtos::FertilizeCreateInput.new(
            name: "Test Fertilize"
          )

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:create_for_user).raises(StandardError.new("Name can't be blank"))

          assert_raises(StandardError, "Name can't be blank") do
            @interactor.call(input_dto)
          end
        end

        test "should call on_failure when user lookup raises RecordNotFound" do
          input_dto = Domain::Fertilize::Dtos::FertilizeCreateInput.new(name: "X")
          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).raises(
            Domain::Shared::Exceptions::RecordNotFound, "User not found"
          )
          @mock_output_port.expects(:on_failure).with(instance_of(Domain::Fertilize::Dtos::FertilizeCreateFailure))

          @interactor.call(input_dto)
        end
      end
    end
  end
end
