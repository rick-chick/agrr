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
            logger: Adapters::Logger::Gateways::RailsLoggerGateway.new,
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

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:update_for_user).with(@user, 1, { name: "Updated Fertilize", n: 15.0 }).returns(updated_fertilize_entity)
          @mock_output_port.expects(:on_success).with(updated_fertilize_entity)

          @interactor.call(input_dto)
        end

        test "should raise error when non-admin user tries to change is_reference flag" do
          input_dto = Domain::Fertilize::Dtos::FertilizeUpdateInputDto.new(
            fertilize_id: 1,
            is_reference: true
          )

          current_entity = mock
          current_entity.expects(:is_reference).returns(false)
          entity = mock
          persisted = mock
          bundle = Domain::Fertilize::Dtos::AuthorizedFertilizeLoadedDto.new(fertilize_entity: entity, persisted_fertilize: persisted)

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:find_authorized_for_edit).with(@user, 1).returns(current_entity)
          @mock_translator.expects(:t).with("fertilizes.flash.reference_flag_admin_only").returns("admin only")
          @mock_gateway.expects(:find_authorized_fertilize_loaded_bundle!).with(@user, 1, for_edit: true).returns(bundle)
          received = nil
          @mock_output_port.expects(:on_failure).with { |dto| received = dto }

          @interactor.call(input_dto)

          assert_instance_of Domain::Fertilize::Dtos::FertilizeUpdateFailureDto, received
          assert_equal "admin only", received.message
          assert_equal bundle, received.reload_bundle
        end

        test "should allow admin user to change is_reference flag" do
          admin_user = create(:user, admin: true)
          admin_user_id = admin_user.id
          admin_interactor = FertilizeUpdateInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway,
            user_id: admin_user_id,
            logger: Adapters::Logger::Gateways::RailsLoggerGateway.new,
            translator: Adapters::Translators::RailsTranslator.new,
            user_lookup: Adapters::Shared::Gateways::UserActiveRecordGateway.new
          )

          input_dto = Domain::Fertilize::Dtos::FertilizeUpdateInputDto.new(
            fertilize_id: 1,
            is_reference: true
          )

          current_entity = mock
          current_entity.expects(:is_reference).returns(false)
          updated_fertilize_entity = mock

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(admin_user_id).returns(admin_user)
          @mock_gateway.expects(:find_authorized_for_edit).with(admin_user, 1).returns(current_entity)
          @mock_gateway.expects(:update_for_user).with(admin_user, 1, { is_reference: true }).returns(updated_fertilize_entity)
          @mock_output_port.expects(:on_success).with(updated_fertilize_entity)

          admin_interactor.call(input_dto)
        end

        test "should handle update failure" do
          input_dto = Domain::Fertilize::Dtos::FertilizeUpdateInputDto.new(
            fertilize_id: 1,
            name: "Updated Fertilize"
          )

          entity = mock
          persisted = mock
          bundle = Domain::Fertilize::Dtos::AuthorizedFertilizeLoadedDto.new(fertilize_entity: entity, persisted_fertilize: persisted)

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:update_for_user).raises(StandardError.new("Update failed"))
          @mock_gateway.expects(:find_authorized_fertilize_loaded_bundle!).with(@user, 1, for_edit: true).returns(bundle)
          received = nil
          @mock_output_port.expects(:on_failure).with { |dto| received = dto }

          @interactor.call(input_dto)

          assert_instance_of Domain::Fertilize::Dtos::FertilizeUpdateFailureDto, received
          assert_equal "Update failed", received.message
          assert_equal bundle, received.reload_bundle
        end

        test "on_failure has nil reload_bundle when user lookup raises" do
          input_dto = Domain::Fertilize::Dtos::FertilizeUpdateInputDto.new(fertilize_id: 1, name: "x")

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).raises(StandardError, "no user")
          @mock_gateway.expects(:update_for_user).never
          @mock_gateway.expects(:find_authorized_fertilize_loaded_bundle!).never
          received = nil
          @mock_output_port.expects(:on_failure).with { |dto| received = dto }

          @interactor.call(input_dto)

          assert_instance_of Domain::Fertilize::Dtos::FertilizeUpdateFailureDto, received
          assert_equal "no user", received.message
          assert_nil received.reload_bundle
        end

        test "on_failure has nil reload_bundle when reload bundle raises" do
          input_dto = Domain::Fertilize::Dtos::FertilizeUpdateInputDto.new(fertilize_id: 1, name: "x")

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:update_for_user).raises(StandardError.new("Update failed"))
          @mock_gateway.expects(:find_authorized_fertilize_loaded_bundle!).with(@user, 1, for_edit: true).raises(StandardError, "reload failed")
          received = nil
          @mock_output_port.expects(:on_failure).with { |dto| received = dto }

          @interactor.call(input_dto)

          assert_instance_of Domain::Fertilize::Dtos::FertilizeUpdateFailureDto, received
          assert_equal "Update failed", received.message
          assert_nil received.reload_bundle
        end
      end
    end
  end
end
