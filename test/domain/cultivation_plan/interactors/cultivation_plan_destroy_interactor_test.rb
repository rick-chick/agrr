# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class CultivationPlanDestroyInteractorTest < DomainLibTestCase
        FakeTranslator = Struct.new(:dummy) do
          def t(key, **options)
            I18n.t(key, **options)
          end
        end

        setup do
          @user_id = 1
          @user = stub(id: @user_id, admin?: false)
          @mock_gateway = mock
          @mock_output_port = mock
          @mock_user_lookup = mock
          @interactor = CultivationPlanDestroyInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway,
            user_id: @user_id,
            translator: FakeTranslator.new(nil),
            user_lookup: @mock_user_lookup
          )
        end

        test "calls on_success when deletion schedules undo" do
          plan_id = 1
          undo_response = mock
          destroy_output_dto = mock

          @mock_user_lookup.expects(:find).with(@user_id).returns(@user)
          stub_plan_access_find_private_owned!(@user, plan_id)
          @mock_gateway.expects(:private_owned_plan_display_name).with(user: @user, plan_id: plan_id).returns("DN")
          expected_toast = I18n.t("plans.undo.toast", name: "DN")
          @mock_gateway.expects(:delete).with(plan_id, @user, toast_message: expected_toast).returns(undo_response)
          Domain::CultivationPlan::Dtos::CultivationPlanDestroyOutput
            .expects(:new).with(undo: undo_response).returns(destroy_output_dto)
          @mock_output_port.expects(:on_success).with(destroy_output_dto)

          @interactor.call(plan_id)
        end

        test "returns not found error when plan missing" do
          plan_id = 1
          error_dto = mock

          @mock_user_lookup.expects(:find).with(@user_id).returns(@user)
          stub_plan_access_find_private_owned!(
            @user,
            plan_id,
            error: Domain::Shared::Exceptions::RecordNotFound.new("nf")
          )
          @mock_gateway.expects(:private_owned_plan_display_name).never
          @mock_gateway.expects(:delete).never
          Domain::Shared::Dtos::Error.expects(:new).with(I18n.t("plans.errors.not_found")).returns(error_dto)
          @mock_output_port.expects(:on_failure).with(error_dto)

          @interactor.call(plan_id)
        end

        test "returns delete failed error when restrictions prevent deletion" do
          plan_id = 1
          error_dto = mock

          @mock_user_lookup.expects(:find).with(@user_id).returns(@user)
          stub_plan_access_find_private_owned!(@user, plan_id)
          @mock_gateway.expects(:private_owned_plan_display_name).with(user: @user, plan_id: plan_id).returns("N")
          @mock_gateway.expects(:delete).with(plan_id, @user, toast_message: I18n.t("plans.undo.toast", name: "N")).raises(
            Domain::Shared::Exceptions::AssociationInUse, "x"
          )
          Domain::Shared::Dtos::Error.expects(:new).with(I18n.t("plans.errors.delete_failed")).returns(error_dto)
          @mock_output_port.expects(:on_failure).with(error_dto)

          @interactor.call(plan_id)
        end

        test "returns delete failed error when invalid foreign key occurs" do
          plan_id = 1
          error_dto = mock

          @mock_user_lookup.expects(:find).with(@user_id).returns(@user)
          stub_plan_access_find_private_owned!(@user, plan_id)
          @mock_gateway.expects(:private_owned_plan_display_name).with(user: @user, plan_id: plan_id).returns("N")
          @mock_gateway.expects(:delete).with(plan_id, @user, toast_message: I18n.t("plans.undo.toast", name: "N")).raises(
            Domain::Shared::Exceptions::AssociationInUse, "x"
          )
          Domain::Shared::Dtos::Error.expects(:new).with(I18n.t("plans.errors.delete_failed")).returns(error_dto)
          @mock_output_port.expects(:on_failure).with(error_dto)

          @interactor.call(plan_id)
        end

        test "returns delete error when undo scheduling fails" do
          plan_id = 1
          error_dto = mock

          @mock_user_lookup.expects(:find).with(@user_id).returns(@user)
          stub_plan_access_find_private_owned!(@user, plan_id)
          @mock_gateway.expects(:private_owned_plan_display_name).with(user: @user, plan_id: plan_id).returns("N")
          deletion_error = Domain::DeletionUndo::Exceptions::DeletionUndoError.new("Undo error")
          @mock_gateway.expects(:delete).with(plan_id, @user, toast_message: I18n.t("plans.undo.toast", name: "N")).raises(deletion_error)
          Domain::Shared::Dtos::Error
            .expects(:new).with(I18n.t("plans.errors.delete_error", message: "Undo error")).returns(error_dto)
          @mock_output_port.expects(:on_failure).with(error_dto)

          @interactor.call(plan_id)
        end

        test "propagates StandardError from gateway" do
          plan_id = 1

          @mock_user_lookup.expects(:find).with(@user_id).returns(@user)
          stub_plan_access_find_private_owned!(@user, plan_id)
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
