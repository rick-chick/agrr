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
            translator: @mock_translator,
            user_lookup: Adapters::Shared::Gateways::UserActiveRecordGateway.new
          )
        end

        test "should update fertilize successfully for regular user" do
          input_dto = Domain::Fertilize::Dtos::FertilizeUpdateInputDto.new(
            fertilize_id: 1,
            name: "Updated Fertilize",
            n: 15.0
          )

          updated_fertilize_entity = mock
          current_entity = mock
          current_entity.expects(:is_reference).at_least_once.returns(false)

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:find_authorized_for_edit).with(@user, 1, access_filter: anything).returns(current_entity)
          @mock_gateway.expects(:update_for_user).with(@user, 1, instance_of(Hash), access_filter: anything).returns(updated_fertilize_entity)
          @mock_output_port.expects(:on_success).with(updated_fertilize_entity)

          @interactor.call(input_dto)
        end

        test "should call on_failure with policy when gateway update denies" do
          input_dto = Domain::Fertilize::Dtos::FertilizeUpdateInputDto.new(
            fertilize_id: 1,
            name: "x"
          )

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).returns(@user)
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
          input_dto = Domain::Fertilize::Dtos::FertilizeUpdateInputDto.new(
            fertilize_id: 1,
            is_reference: true
          )

          current_entity = mock
          current_entity.expects(:is_reference).at_least_once.returns(false)
          entity = mock
          persisted = mock
          bundle = Domain::Fertilize::Dtos::AuthorizedFertilizeLoadedDto.new(fertilize_entity: entity, persisted_fertilize: persisted)

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:find_authorized_for_edit).with(@user, 1, access_filter: anything).returns(current_entity)
          @mock_translator.expects(:t).with("fertilizes.flash.reference_flag_admin_only").returns("admin only")
          @mock_gateway.expects(:find_authorized_fertilize_loaded_bundle!).with(@user, 1, for_edit: true, access_filter: anything).returns(bundle)
          received = nil
          @mock_output_port.expects(:on_failure).with { |dto| received = dto }

          @interactor.call(input_dto)

          assert_instance_of Domain::Fertilize::Dtos::FertilizeUpdateFailureDto, received
          assert_equal "admin only", received.message
          assert_equal persisted, received.form_fertilize
        end

        test "should allow admin user to change is_reference flag" do
          admin_user = create(:user, admin: true)
          admin_user_id = admin_user.id
          admin_interactor = FertilizeUpdateInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway,
            user_id: admin_user_id,
            translator: Adapters::Translators::RailsTranslator.new,
            user_lookup: Adapters::Shared::Gateways::UserActiveRecordGateway.new
          )

          input_dto = Domain::Fertilize::Dtos::FertilizeUpdateInputDto.new(
            fertilize_id: 1,
            is_reference: true
          )

          current_entity = mock
          current_entity.expects(:is_reference).at_least_once.returns(false)
          updated_fertilize_entity = mock

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(admin_user_id).returns(admin_user)
          @mock_gateway.expects(:find_authorized_for_edit).with(admin_user, 1, access_filter: anything).returns(current_entity)
          @mock_gateway.expects(:update_for_user).with(admin_user, 1, instance_of(Hash), access_filter: anything).returns(updated_fertilize_entity)
          @mock_output_port.expects(:on_success).with(updated_fertilize_entity)

          admin_interactor.call(input_dto)
        end

        test "should handle update failure" do
          input_dto = Domain::Fertilize::Dtos::FertilizeUpdateInputDto.new(
            fertilize_id: 1,
            name: "Updated Fertilize"
          )

          current_entity = mock
          current_entity.expects(:is_reference).at_least_once.returns(false)

          entity = mock
          persisted = mock
          bundle = Domain::Fertilize::Dtos::AuthorizedFertilizeLoadedDto.new(fertilize_entity: entity, persisted_fertilize: persisted)

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:find_authorized_for_edit).with(@user, 1, access_filter: anything).returns(current_entity)
          @mock_gateway.expects(:update_for_user).raises(Domain::Shared::Exceptions::RecordInvalid.new("Update failed"))
          @mock_gateway.expects(:find_authorized_fertilize_loaded_bundle!).with(@user, 1, for_edit: true, access_filter: anything).returns(bundle)
          received = nil
          @mock_output_port.expects(:on_failure).with { |dto| received = dto }

          @interactor.call(input_dto)

          assert_instance_of Domain::Fertilize::Dtos::FertilizeUpdateFailureDto, received
          assert_equal "Update failed", received.message
          assert_equal persisted, received.form_fertilize
        end

        test "propagates StandardError when user lookup raises" do
          input_dto = Domain::Fertilize::Dtos::FertilizeUpdateInputDto.new(fertilize_id: 1, name: "x")

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).raises(StandardError, "no user")
          @mock_gateway.expects(:find_authorized_for_edit).never
          @mock_gateway.expects(:update_for_user).never
          @mock_gateway.expects(:find_authorized_fertilize_loaded_bundle!).never

          assert_raises(StandardError, "no user") do
            @interactor.call(input_dto)
          end
        end

        test "on_failure uses model_for_edit fallback when reload bundle raises RecordNotFound" do
          input_dto = Domain::Fertilize::Dtos::FertilizeUpdateInputDto.new(fertilize_id: 1, name: "x")

          current_entity = mock
          current_entity.expects(:is_reference).at_least_once.returns(false)
          fallback_model = mock

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:find_authorized_for_edit).with(@user, 1, access_filter: anything).returns(current_entity)
          @mock_gateway.expects(:update_for_user).raises(Domain::Shared::Exceptions::RecordInvalid.new("Update failed"))
          @mock_gateway.expects(:find_authorized_fertilize_loaded_bundle!).with(@user, 1, for_edit: true, access_filter: anything).raises(
            Domain::Shared::Exceptions::RecordNotFound.new("reload failed")
          )
          @mock_gateway.expects(:find_authorized_model_for_edit).with(@user, 1, access_filter: anything).returns(fallback_model)
          received = nil
          @mock_output_port.expects(:on_failure).with { |dto| received = dto }

          @interactor.call(input_dto)

          assert_instance_of Domain::Fertilize::Dtos::FertilizeUpdateFailureDto, received
          assert_equal "Update failed", received.message
          assert_equal fallback_model, received.form_fertilize
        end

        test "on_failure has nil form_fertilize when reload and fallback both fail" do
          input_dto = Domain::Fertilize::Dtos::FertilizeUpdateInputDto.new(fertilize_id: 1, name: "x")

          current_entity = mock
          current_entity.expects(:is_reference).at_least_once.returns(false)

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:find_authorized_for_edit).with(@user, 1, access_filter: anything).returns(current_entity)
          @mock_gateway.expects(:update_for_user).raises(Domain::Shared::Exceptions::RecordInvalid.new("Update failed"))
          @mock_gateway.expects(:find_authorized_fertilize_loaded_bundle!).with(@user, 1, for_edit: true, access_filter: anything).raises(
            Domain::Shared::Exceptions::RecordNotFound.new("reload failed")
          )
          @mock_gateway.expects(:find_authorized_model_for_edit).with(@user, 1, access_filter: anything).raises(
            Domain::Shared::Exceptions::RecordNotFound.new("edit failed")
          )
          received = nil
          @mock_output_port.expects(:on_failure).with { |dto| received = dto }

          @interactor.call(input_dto)

          assert_instance_of Domain::Fertilize::Dtos::FertilizeUpdateFailureDto, received
          assert_equal "Update failed", received.message
          assert_nil received.form_fertilize
        end
      end
    end
  end
end
