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
          @mock_translator = mock
          @interactor = FarmDestroyInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway,
            user_id: @user_id,
            logger: Adapters::Logger::Gateways::RailsLoggerGateway.new,
            translator: @mock_translator
          )
        end

        test "should destroy farm successfully when no crop plans exist" do
          farm = create(:farm, user: @user, name: "Test Farm")
          farm_id = farm.id

          User.expects(:find).with(@user_id).returns(@user)
          Domain::Shared::Policies::FarmPolicy.expects(:find_editable!).with(::Farm, @user, farm_id.to_s).returns(farm)
          @mock_translator.expects(:t).with('flash.farms.deleted', name: "Test Farm").returns("Test Farm deleted")
          @mock_output_port.expects(:on_success).with(instance_of(Domain::Farm::Dtos::FarmDestroyOutputDto))

          gateway = Adapters::DeletionUndo::Gateways::DeletionUndoActiveRecordGateway.new
          interactor = FarmDestroyInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway,
            user_id: @user_id,
            logger: Adapters::Logger::Gateways::RailsLoggerGateway.new,
            translator: @mock_translator,
            deletion_undo_gateway: gateway
          )

          interactor.call(farm_id.to_s)
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