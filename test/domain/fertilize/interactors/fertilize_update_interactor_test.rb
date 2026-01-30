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
          @interactor = FertilizeUpdateInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway,
            user_id: @user_id
          )
        end

        test "should update fertilize successfully for regular user" do
          input_dto = Domain::Fertilize::Dtos::FertilizeUpdateInputDto.new(
            fertilize_id: 1,
            name: "Updated Fertilize",
            n: 15.0
          )

          fertilize_model = mock
          updated_fertilize_entity = mock

          User.expects(:find).with(@user_id).returns(@user)
          Domain::Shared::Policies::FertilizePolicy.expects(:find_editable!).with(::Fertilize, @user, 1).returns(fertilize_model)
          Domain::Shared::Policies::FertilizePolicy.expects(:apply_update!).with(@user, fertilize_model, { name: "Updated Fertilize", n: 15.0 })
          fertilize_model.expects(:errors).returns(mock)
          fertilize_model.errors.expects(:any?).returns(false)
          fertilize_model.expects(:reload).returns(fertilize_model)
          Domain::Fertilize::Entities::FertilizeEntity.expects(:from_model).with(fertilize_model).returns(updated_fertilize_entity)
          @mock_output_port.expects(:on_success).with(updated_fertilize_entity)

          @interactor.call(input_dto)
        end

        test "should raise error when non-admin user tries to change is_reference flag" do
          input_dto = Domain::Fertilize::Dtos::FertilizeUpdateInputDto.new(
            fertilize_id: 1,
            is_reference: true
          )

          fertilize_model = mock
          fertilize_model.expects(:is_reference).returns(false)

          User.expects(:find).with(@user_id).returns(@user)
          Domain::Shared::Policies::FertilizePolicy.expects(:find_editable!).with(::Fertilize, @user, 1).returns(fertilize_model)
          @mock_output_port.expects(:on_failure).with(instance_of(Domain::Shared::Dtos::ErrorDto))

          @interactor.call(input_dto)
        end

        test "should allow admin user to change is_reference flag" do
          admin_user = create(:user, admin: true)
          admin_user_id = admin_user.id
          admin_interactor = FertilizeUpdateInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway,
            user_id: admin_user_id
          )

          input_dto = Domain::Fertilize::Dtos::FertilizeUpdateInputDto.new(
            fertilize_id: 1,
            is_reference: true
          )

          fertilize_model = mock
          fertilize_model.expects(:is_reference).returns(false)
          updated_fertilize_entity = mock

          User.expects(:find).with(admin_user_id).returns(admin_user)
          Domain::Shared::Policies::FertilizePolicy.expects(:find_editable!).with(::Fertilize, admin_user, 1).returns(fertilize_model)
          Domain::Shared::Policies::FertilizePolicy.expects(:apply_update!).with(admin_user, fertilize_model, { is_reference: true })
          fertilize_model.expects(:errors).returns(mock)
          fertilize_model.errors.expects(:any?).returns(false)
          fertilize_model.expects(:reload).returns(fertilize_model)
          Domain::Fertilize::Entities::FertilizeEntity.expects(:from_model).with(fertilize_model).returns(updated_fertilize_entity)
          @mock_output_port.expects(:on_success).with(updated_fertilize_entity)

          admin_interactor.call(input_dto)
        end

        test "should handle update failure" do
          input_dto = Domain::Fertilize::Dtos::FertilizeUpdateInputDto.new(
            fertilize_id: 1,
            name: "Updated Fertilize"
          )

          fertilize_model = mock
          fertilize_model.expects(:errors).returns(mock)
          fertilize_model.errors.expects(:full_messages).returns(["Update failed"])
          fertilize_model.errors.expects(:any?).returns(true)

          User.expects(:find).with(@user_id).returns(@user)
          Domain::Shared::Policies::FertilizePolicy.expects(:find_editable!).returns(fertilize_model)
          Domain::Shared::Policies::FertilizePolicy.expects(:apply_update!).returns(fertilize_model)
          @mock_output_port.expects(:on_failure).with(instance_of(Domain::Shared::Dtos::ErrorDto))

          @interactor.call(input_dto)
        end
      end
    end
  end
end