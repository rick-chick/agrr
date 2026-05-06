# frozen_string_literal: true

require "test_helper"
require_dependency "deletion_undo/manager"

module Domain
  module CultivationPlan
    module Interactors
      class CultivationPlanDestroyInteractorTest < ActiveSupport::TestCase
        setup do
          @user = create(:user)
          @user_id = @user.id
          @mock_gateway = mock
          @mock_output_port = mock
          @mock_translator = Adapters::Translators::RailsTranslator.new
          @interactor = CultivationPlanDestroyInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway,
            user_id: @user_id,
            logger: Adapters::Logger::Gateways::RailsLoggerGateway.new,
            translator: @mock_translator,
            user_lookup: Adapters::Shared::Gateways::UserActiveRecordGateway.new
          )
        end

        test "calls on_success when deletion schedules undo" do
          plan_id = 1
          undo_response = mock
          destroy_output_dto = mock

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:private_owned_plan_display_name).with(user: @user, plan_id: plan_id).returns("DN")
          expected_toast = I18n.t("plans.undo.toast", name: "DN")
          @mock_gateway.expects(:destroy).with(plan_id, @user, toast_message: expected_toast).returns(undo_response)
          Domain::CultivationPlan::Dtos::CultivationPlanDestroyOutputDto
            .expects(:new).with(undo: undo_response).returns(destroy_output_dto)
          @mock_output_port.expects(:on_success).with(destroy_output_dto)

          @interactor.call(plan_id)
        end

        test "returns not found error when plan missing" do
          plan_id = 1
          error_dto = mock

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:private_owned_plan_display_name).with(user: @user, plan_id: plan_id).raises(
            Domain::Shared::Exceptions::RecordNotFound, "nf"
          )
          @mock_gateway.expects(:destroy).never
          Domain::Shared::Dtos::ErrorDto.expects(:new).with(I18n.t("plans.errors.not_found")).returns(error_dto)
          @mock_output_port.expects(:on_failure).with(error_dto)

          @interactor.call(plan_id)
        end

        test "returns not found error when policy denies access" do
          plan_id = 1
          error_dto = mock

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:private_owned_plan_display_name).with(user: @user, plan_id: plan_id).raises(Domain::Shared::Policies::PolicyPermissionDenied)
          @mock_gateway.expects(:destroy).never
          Domain::Shared::Dtos::ErrorDto.expects(:new).with(I18n.t("plans.errors.not_found")).returns(error_dto)
          @mock_output_port.expects(:on_failure).with(error_dto)

          @interactor.call(plan_id)
        end

        test "returns delete failed error when restrictions prevent deletion" do
          plan_id = 1
          error_dto = mock

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:private_owned_plan_display_name).with(user: @user, plan_id: plan_id).returns("N")
          @mock_gateway.expects(:destroy).with(plan_id, @user, toast_message: I18n.t("plans.undo.toast", name: "N")).raises(
            Domain::Shared::Exceptions::AssociationInUse, "x"
          )
          Domain::Shared::Dtos::ErrorDto.expects(:new).with(I18n.t("plans.errors.delete_failed")).returns(error_dto)
          @mock_output_port.expects(:on_failure).with(error_dto)

          @interactor.call(plan_id)
        end

        test "returns delete failed error when invalid foreign key occurs" do
          plan_id = 1
          error_dto = mock

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:private_owned_plan_display_name).with(user: @user, plan_id: plan_id).returns("N")
          @mock_gateway.expects(:destroy).with(plan_id, @user, toast_message: I18n.t("plans.undo.toast", name: "N")).raises(
            Domain::Shared::Exceptions::AssociationInUse, "x"
          )
          Domain::Shared::Dtos::ErrorDto.expects(:new).with(I18n.t("plans.errors.delete_failed")).returns(error_dto)
          @mock_output_port.expects(:on_failure).with(error_dto)

          @interactor.call(plan_id)
        end

        test "returns delete error when undo scheduling fails" do
          plan_id = 1
          error_dto = mock

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:private_owned_plan_display_name).with(user: @user, plan_id: plan_id).returns("N")
          deletion_error = DeletionUndo::Error.new("Undo error")
          @mock_gateway.expects(:destroy).with(plan_id, @user, toast_message: I18n.t("plans.undo.toast", name: "N")).raises(deletion_error)
          Domain::Shared::Dtos::ErrorDto
            .expects(:new).with(I18n.t("plans.errors.delete_error", message: "Undo error")).returns(error_dto)
          @mock_output_port.expects(:on_failure).with(error_dto)

          @interactor.call(plan_id)
        end

        test "propagates StandardError from gateway" do
          plan_id = 1

          Adapters::Shared::Gateways::UserActiveRecordGateway.any_instance.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:private_owned_plan_display_name).with(user: @user, plan_id: plan_id).raises(StandardError.new("Unexpected error"))
          @mock_output_port.expects(:on_failure).never

          err = assert_raises(StandardError) do
            @interactor.call(plan_id)
          end
          assert_equal "Unexpected error", err.message
        end
      end
    end
  end
end
