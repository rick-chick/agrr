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
            translator: @mock_translator,
            user_lookup: Adapters::Shared::Gateways::UserActiveRecordGateway.new
          )
        end

        test "should destroy farm successfully when no crop plans exist" do
          farm = create(:farm, user: @user, name: "Test Farm")
          farm_id = farm.id
          mock_undo = mock
          mock_undo.stubs(:expires_at).returns(Time.current + 5.minutes)
          farm_entity = stub(name: "Test Farm")

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).returns(@user)
          access_filter = Domain::Shared::Policies::FarmPolicy.record_access_filter(@user)
          @mock_gateway.expects(:find_authorized_for_edit).with(@user, farm_id.to_s, access_filter: access_filter).returns(farm_entity)
          @mock_translator.expects(:t).with("flash.farms.deleted", name: "Test Farm").returns("toast-msg")
          @mock_gateway.expects(:soft_destroy_with_undo).with(
            user: @user,
            farm_id: farm_id.to_s,
            auto_hide_after: 5000,
            toast_message: "toast-msg",
            access_filter: access_filter
          ).returns({ success: true, undo_entity: mock_undo, farm_name: "Test Farm" })

          @mock_output_port.expects(:on_success).with(instance_of(Domain::Farm::Dtos::FarmDestroyOutputDto))

          interactor = FarmDestroyInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway,
            user_id: @user_id,
            translator: @mock_translator,
            user_lookup: Adapters::Shared::Gateways::UserActiveRecordGateway.new
          )

          interactor.call(farm_id.to_s)
        end

        test "calls on_failure when policy permission denied" do
          farm_id = 1

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:find_authorized_for_edit).with(@user, farm_id, access_filter: instance_of(Domain::Shared::ReferenceRecordAccessFilter)).raises(Domain::Shared::Policies::PolicyPermissionDenied)

          received = nil
          @mock_output_port.expects(:on_failure).with(instance_of(Domain::Shared::Policies::PolicyPermissionDenied)) { |e| received = e }

          @interactor.call(farm_id)

          assert_instance_of Domain::Shared::Policies::PolicyPermissionDenied, received
        end
      end
    end
  end
end
