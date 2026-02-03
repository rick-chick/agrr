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
          @interactor = CultivationPlanDestroyInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway,
            user_id: @user_id
          )
        end

        test "calls on_success when deletion schedules undo" do
          plan_id = 1
          undo_response = mock
          destroy_output_dto = mock

          User.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:destroy).with(plan_id, @user).returns(undo_response)
          Domain::CultivationPlan::Dtos::CultivationPlanDestroyOutputDto
            .expects(:new).with(undo: undo_response).returns(destroy_output_dto)
          @mock_output_port.expects(:on_success).with(destroy_output_dto)

          @interactor.call(plan_id)
        end

        test "returns not found error when plan missing" do
          plan_id = 1
          error_dto = mock

          User.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:destroy).with(plan_id, @user).raises(ActiveRecord::RecordNotFound)
          Domain::Shared::Dtos::ErrorDto.expects(:new).with(I18n.t('plans.errors.not_found')).returns(error_dto)
          @mock_output_port.expects(:on_failure).with(error_dto)

          @interactor.call(plan_id)
        end

        test "returns not found error when policy denies access" do
          plan_id = 1
          error_dto = mock

          User.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:destroy).with(plan_id, @user).raises(PolicyPermissionDenied)
          Domain::Shared::Dtos::ErrorDto.expects(:new).with(I18n.t('plans.errors.not_found')).returns(error_dto)
          @mock_output_port.expects(:on_failure).with(error_dto)

          @interactor.call(plan_id)
        end

        test "returns delete failed error when restrictions prevent deletion" do
          plan_id = 1
          error_dto = mock

          User.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:destroy).with(plan_id, @user).raises(ActiveRecord::DeleteRestrictionError)
          Domain::Shared::Dtos::ErrorDto.expects(:new).with(I18n.t('plans.errors.delete_failed')).returns(error_dto)
          @mock_output_port.expects(:on_failure).with(error_dto)

          @interactor.call(plan_id)
        end

        test "returns delete failed error when invalid foreign key occurs" do
          plan_id = 1
          error_dto = mock

          User.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:destroy).with(plan_id, @user).raises(ActiveRecord::InvalidForeignKey)
          Domain::Shared::Dtos::ErrorDto.expects(:new).with(I18n.t('plans.errors.delete_failed')).returns(error_dto)
          @mock_output_port.expects(:on_failure).with(error_dto)

          @interactor.call(plan_id)
        end

        test "returns delete error when undo scheduling fails" do
          plan_id = 1
          error_dto = mock

          User.expects(:find).with(@user_id).returns(@user)
          deletion_error = DeletionUndo::Error.new("Undo error")
          @mock_gateway.expects(:destroy).with(plan_id, @user).raises(deletion_error)
          Domain::Shared::Dtos::ErrorDto
            .expects(:new).with(I18n.t('plans.errors.delete_error', message: "Undo error")).returns(error_dto)
          @mock_output_port.expects(:on_failure).with(error_dto)

          @interactor.call(plan_id)
        end

        test "returns generic error when unexpected exception occurs" do
          plan_id = 1
          error_dto = mock

          User.expects(:find).with(@user_id).returns(@user)
          @mock_gateway.expects(:destroy).with(plan_id, @user).raises(StandardError.new("Unexpected error"))
          Domain::Shared::Dtos::ErrorDto
            .expects(:new).with("Unexpected error").returns(error_dto)
          @mock_output_port.expects(:on_failure).with(error_dto)

          @interactor.call(plan_id)
        end
      end
    end
  end
end
