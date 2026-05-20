# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Fertilize
    module Interactors
      class FertilizeUpdateInteractorTest < DomainLibTestCase
        setup do
          @user_id = 1
          @user = stub(id: @user_id, admin?: false)
          @mock_gateway = mock
          @mock_output_port = mock
          @mock_translator = mock
          @mock_user_lookup = mock
          @interactor = FertilizeUpdateInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway,
            user_id: @user_id,
            translator: @mock_translator,
            user_lookup: @mock_user_lookup
          )
        end

        test "should update fertilize successfully for regular user" do
          input_dto = Domain::Fertilize::Dtos::FertilizeUpdateInput.new(
            fertilize_id: 1,
            name: "Updated Fertilize",
            n: 15.0
          )

          updated_fertilize_entity = mock
          current_entity = mock
          current_entity.expects(:is_reference).at_least_once.returns(false)

          @mock_user_lookup.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:find_authorized_for_edit).with(@user, 1, access_filter: anything).returns(current_entity)
          @mock_gateway.expects(:update_for_user).with(@user, 1, instance_of(Hash), access_filter: anything).returns(updated_fertilize_entity)
          @mock_output_port.expects(:on_success).with(updated_fertilize_entity)

          @interactor.call(input_dto)
        end

        test "should call on_failure with policy when gateway update denies" do
          input_dto = Domain::Fertilize::Dtos::FertilizeUpdateInput.new(
            fertilize_id: 1,
            name: "x"
          )

          @mock_user_lookup.expects(:find).with(@user_id).returns(@user)
          current_entity = mock
          current_entity.expects(:is_reference).at_least_once.returns(false)
          @mock_gateway.expects(:find_authorized_for_edit).with(@user, 1, access_filter: anything).returns(current_entity)
          @mock_gateway.expects(:update_for_user).raises(Domain::Shared::Policies::PolicyPermissionDenied)

          received = nil
          @mock_output_port.expects(:on_failure).with(instance_of(Domain::Shared::Policies::PolicyPermissionDenied)) { |e| received = e }

          @interactor.call(input_dto)

          assert_instance_of Domain::Shared::Policies::PolicyPermissionDenied, received
        end

        test "should raise error when non-admin user tries to change is_reference flag" do
          input_dto = Domain::Fertilize::Dtos::FertilizeUpdateInput.new(
            fertilize_id: 1,
            is_reference: true
          )

          current_entity = mock
          current_entity.expects(:is_reference).at_least_once.returns(false)
          current_entity.stubs(:id).returns(1)
          current_entity.stubs(:name).returns("F")
          current_entity.stubs(:n).returns(nil)
          current_entity.stubs(:p).returns(nil)
          current_entity.stubs(:k).returns(nil)
          current_entity.stubs(:description).returns(nil)
          current_entity.stubs(:package_size).returns(nil)
          current_entity.stubs(:region).returns(nil)
          current_entity.stubs(:user_id).returns(42)

          @mock_user_lookup.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:find_authorized_for_edit).with(@user, 1, access_filter: anything).returns(current_entity)
          @mock_translator.expects(:t).with("fertilizes.flash.reference_flag_admin_only").returns("admin only")
          received = nil
          @mock_output_port.expects(:on_failure).with { |dto| received = dto }

          @interactor.call(input_dto)

          assert_instance_of Domain::Fertilize::Dtos::FertilizeUpdateFailure, received
          assert_equal "admin only", received.message
          assert_instance_of Domain::Fertilize::Dtos::FertilizeMasterFormSnapshot, received.master_form_snapshot
        end

        test "should allow admin user to change is_reference flag" do
          admin_user_id = 2
          admin_user = stub(id: admin_user_id, admin?: true)
          admin_user_lookup = mock
          admin_interactor = FertilizeUpdateInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway,
            user_id: admin_user_id,
            translator: @mock_translator,
            user_lookup: admin_user_lookup
          )

          input_dto = Domain::Fertilize::Dtos::FertilizeUpdateInput.new(
            fertilize_id: 1,
            is_reference: true
          )

          current_entity = mock
          current_entity.expects(:is_reference).at_least_once.returns(false)
          updated_fertilize_entity = mock

          admin_user_lookup.expects(:find).with(admin_user_id).returns(admin_user)
          @mock_gateway.expects(:find_authorized_for_edit).with(admin_user, 1, access_filter: anything).returns(current_entity)
          @mock_gateway.expects(:update_for_user).with(admin_user, 1, instance_of(Hash), access_filter: anything).returns(updated_fertilize_entity)
          @mock_output_port.expects(:on_success).with(updated_fertilize_entity)

          admin_interactor.call(input_dto)
        end

        test "should handle update failure" do
          input_dto = Domain::Fertilize::Dtos::FertilizeUpdateInput.new(
            fertilize_id: 1,
            name: "Updated Fertilize"
          )

          current_entity = mock
          current_entity.expects(:is_reference).at_least_once.returns(false)
          current_entity.stubs(:id).returns(1)
          current_entity.stubs(:name).returns("Original")
          current_entity.stubs(:n).returns(nil)
          current_entity.stubs(:p).returns(nil)
          current_entity.stubs(:k).returns(nil)
          current_entity.stubs(:description).returns(nil)
          current_entity.stubs(:package_size).returns(nil)
          current_entity.stubs(:region).returns(nil)
          current_entity.stubs(:user_id).returns(42)

          @mock_user_lookup.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:find_authorized_for_edit).with(@user, 1, access_filter: anything).returns(current_entity)
          @mock_gateway.expects(:update_for_user).raises(Domain::Shared::Exceptions::RecordInvalid.new("Update failed"))
          received = nil
          @mock_output_port.expects(:on_failure).with { |dto| received = dto }

          @interactor.call(input_dto)

          assert_instance_of Domain::Fertilize::Dtos::FertilizeUpdateFailure, received
          assert_equal "Update failed", received.message
          assert_instance_of Domain::Fertilize::Dtos::FertilizeMasterFormSnapshot, received.master_form_snapshot
        end

        test "propagates StandardError when user lookup raises" do
          input_dto = Domain::Fertilize::Dtos::FertilizeUpdateInput.new(fertilize_id: 1, name: "x")

          @mock_user_lookup.expects(:find).with(@user_id).raises(StandardError, "no user")
          @mock_gateway.expects(:find_authorized_for_edit).never
          @mock_gateway.expects(:update_for_user).never
          @mock_gateway.expects(:find_authorized_fertilize_loaded_bundle!).never

          assert_raises(StandardError, "no user") do
            @interactor.call(input_dto)
          end
        end

        test "on_failure has nil master_form_snapshot when entity lookup fails before update" do
          input_dto = Domain::Fertilize::Dtos::FertilizeUpdateInput.new(fertilize_id: 1, name: "x")

          @mock_user_lookup.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:find_authorized_for_edit).with(@user, 1, access_filter: anything).raises(
            Domain::Shared::Exceptions::RecordNotFound.new("not found")
          )
          received = nil
          @mock_output_port.expects(:on_failure).with { |dto| received = dto }

          @interactor.call(input_dto)

          assert_instance_of Domain::Fertilize::Dtos::FertilizeUpdateFailure, received
          assert_equal "not found", received.message
          assert_nil received.master_form_snapshot
        end
      end
    end
  end
end
