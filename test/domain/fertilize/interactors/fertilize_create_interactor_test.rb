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
          @interactor = FertilizeCreateInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway,
            user_id: @user_id
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

          fertilize_model = mock
          fertilize_entity = mock

          User.expects(:find).with(@user_id).returns(@user)
          Domain::Shared::Policies::FertilizePolicy.expects(:build_for_create).with(::Fertilize, @user, {
            name: "Test Fertilize",
            n: 10.0,
            p: 5.0,
            k: 3.0,
            description: nil,
            package_size: nil,
            region: "Kyoto",
            is_reference: false
          }).returns(fertilize_model)
          fertilize_model.expects(:save).returns(true)
          Domain::Fertilize::Entities::FertilizeEntity.expects(:from_model).with(fertilize_model).returns(fertilize_entity)
          @mock_output_port.expects(:on_success).with(fertilize_entity)

          @interactor.call(input_dto)
        end

        test "should raise error when non-admin user tries to create reference fertilize" do
          input_dto = Domain::Fertilize::Dtos::FertilizeCreateInputDto.new(
            name: "Test Reference Fertilize",
            is_reference: true
          )

          User.expects(:find).with(@user_id).returns(@user)
          @mock_output_port.expects(:on_failure).with(instance_of(Domain::Shared::Dtos::ErrorDto))

          @interactor.call(input_dto)
        end

        test "should create reference fertilize for admin user" do
          admin_user = create(:user, admin: true)
          admin_user_id = admin_user.id
          admin_interactor = FertilizeCreateInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway,
            user_id: admin_user_id
          )

          input_dto = Domain::Fertilize::Dtos::FertilizeCreateInputDto.new(
            name: "Test Reference Fertilize",
            is_reference: true
          )

          fertilize_model = mock
          fertilize_entity = mock

          User.expects(:find).with(admin_user_id).returns(admin_user)
          Domain::Shared::Policies::FertilizePolicy.expects(:build_for_create).with(::Fertilize, admin_user, {
            name: "Test Reference Fertilize",
            n: nil,
            p: nil,
            k: nil,
            description: nil,
            package_size: nil,
            region: nil,
            is_reference: true
          }).returns(fertilize_model)
          fertilize_model.expects(:save).returns(true)
          Domain::Fertilize::Entities::FertilizeEntity.expects(:from_model).with(fertilize_model).returns(fertilize_entity)
          @mock_output_port.expects(:on_success).with(fertilize_entity)

          admin_interactor.call(input_dto)
        end

        test "should handle save failure" do
          input_dto = Domain::Fertilize::Dtos::FertilizeCreateInputDto.new(
            name: "Test Fertilize"
          )

          fertilize_model = mock
          errors_mock = mock
          errors_mock.expects(:full_messages).returns(["Name can't be blank"])
          fertilize_model.expects(:errors).returns(errors_mock)

          User.expects(:find).with(@user_id).returns(@user)
          Domain::Shared::Policies::FertilizePolicy.expects(:build_for_create).returns(fertilize_model)
          fertilize_model.expects(:save).returns(false)
          @mock_output_port.expects(:on_failure).with(instance_of(Domain::Shared::Dtos::ErrorDto))

          @interactor.call(input_dto)
        end
      end
    end
  end
end