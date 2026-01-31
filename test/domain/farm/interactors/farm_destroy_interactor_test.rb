# frozen_string_literal: true

require "test_helper"

module Domain
  module Farm
    module Interactors
      class FarmDestroyInteractorTest < ActiveSupport::TestCase
        setup do
          @user = create(:user)
          @user_id = @user.id
          @mock_gateway = mock
          @mock_output_port = mock
          @interactor = FarmDestroyInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway,
            user_id: @user_id
          )
        end

        test "should destroy farm successfully when no crop plans exist" do
          farm_id = 1
          farm_model = mock
          free_crop_plans_mock = mock
          free_crop_plans_mock.expects(:any?).returns(false)
          undo_response = mock
          destroy_output_dto = mock

          User.expects(:find).with(@user_id).returns(@user)
          Domain::Shared::Policies::FarmPolicy.expects(:find_editable!).with(::Farm, @user, farm_id).returns(farm_model)
          farm_model.expects(:free_crop_plans).returns(free_crop_plans_mock)
          farm_model.stubs(:display_name).returns("Test Farm")
          DeletionUndo::Manager.expects(:schedule).with(
            record: farm_model,
            actor: @user,
            toast_message: instance_of(String)
          ).returns(undo_response)
          Domain::Farm::Dtos::FarmDestroyOutputDto.expects(:new).with(undo: undo_response).returns(destroy_output_dto)
          @mock_output_port.expects(:on_success).with(destroy_output_dto)

          @interactor.call(farm_id)
        end

        test "should raise error when farm has crop plans" do
          farm_id = 1
          farm_model = mock
          free_crop_plans_mock = mock
          free_crop_plans_mock.expects(:any?).returns(true)
          free_crop_plans_mock.expects(:count).returns(2)

          User.expects(:find).with(@user_id).returns(@user)
          Domain::Shared::Policies::FarmPolicy.expects(:find_editable!).with(::Farm, @user, farm_id).returns(farm_model)
          farm_model.stubs(:free_crop_plans).returns(free_crop_plans_mock)
          @mock_output_port.expects(:on_failure).with(instance_of(Domain::Shared::Dtos::ErrorDto))

          @interactor.call(farm_id)
        end

        test "should re-raise policy permission denied" do
          farm_id = 1

          User.expects(:find).with(@user_id).returns(@user)
          Domain::Shared::Policies::FarmPolicy.expects(:find_editable!).raises(Domain::Shared::Policies::PolicyPermissionDenied)

          assert_raises(Domain::Shared::Policies::PolicyPermissionDenied) do
            @interactor.call(farm_id)
          end
        end
      end
    end
  end
end