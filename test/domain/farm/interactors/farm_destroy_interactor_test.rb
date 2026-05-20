# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Farm
    module Interactors
      class FarmDestroyInteractorTest < DomainLibTestCase
        setup do
          @user_id = 1
          @user = stub(id: @user_id, admin?: false)
          @mock_gateway = mock
          @mock_output_port = mock
          @mock_translator = mock
          @mock_user_lookup = mock
          @interactor = FarmDestroyInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway,
            user_id: @user_id,
            translator: @mock_translator,
            user_lookup: @mock_user_lookup
          )
        end

        test "should destroy farm successfully when no crop plans exist" do
          farm_id = "5"
          mock_undo = mock
          mock_undo.stubs(:expires_at).returns(Time.utc(2026, 1, 1, 0, 5, 0))
          farm_entity = stub(name: "Test Farm")

          @mock_user_lookup.expects(:find).with(@user_id).returns(@user)
          access_filter = Domain::Shared::Policies::FarmPolicy.record_access_filter(@user)
          @mock_gateway.expects(:find_authorized_for_edit).with(@user, farm_id, access_filter: access_filter).returns(farm_entity)
          @mock_translator.expects(:t).with("flash.farms.deleted", name: "Test Farm").returns("toast-msg")
          @mock_gateway.expects(:soft_destroy_with_undo).with(
            user: @user,
            farm_id: farm_id,
            auto_hide_after: 5000,
            toast_message: "toast-msg",
            access_filter: access_filter
          ).returns({ success: true, undo_entity: mock_undo, farm_name: "Test Farm" })

          @mock_output_port.expects(:on_success).with(instance_of(Domain::Farm::Dtos::FarmDestroyOutput))

          @interactor.call(farm_id)
        end

        test "calls on_failure when policy permission denied" do
          farm_id = 1

          @mock_user_lookup.expects(:find).with(@user_id).returns(@user)
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
