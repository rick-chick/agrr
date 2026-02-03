# frozen_string_literal: true

require "test_helper"

module Adapters
  module CultivationPlan
    module Gateways
      class CultivationPlanActiveRecordGatewayTest < ActiveSupport::TestCase
        def setup
          @gateway = CultivationPlanActiveRecordGateway.new
          @user = create(:user)
          @other_user = create(:user)
          @farm = create(:farm, user: @user)
        end

        test "schedules deletion undo event and returns it" do
          plan = create(:cultivation_plan, farm: @farm, user: @user, plan_name: "My Plan")

          assert_difference("DeletionUndoEvent.count", 1) do
            event = @gateway.destroy(plan.id, @user)

            assert_instance_of DeletionUndoEvent, event
            assert_equal "CultivationPlan", event.resource_type
            assert_equal plan.id.to_s, event.resource_id
            assert_equal @user.id, event.deleted_by_id
            assert_equal "scheduled", event.state
            expected_toast = I18n.t('plans.undo.toast', name: plan.display_name)
            assert_equal expected_toast, event.toast_message
            assert_not_nil event.undo_token
          end

          assert_nil ::CultivationPlan.find_by(id: plan.id)
        end

        test "raises not found error when plan does not exist" do
          error = assert_raises(StandardError) do
            @gateway.destroy(9999, @user)
          end

          assert_equal I18n.t('plans.errors.not_found'), error.message
        end

        test "raises not found error when user is not the owner" do
          plan = create(:cultivation_plan, farm: @farm, user: @user)

          error = assert_raises(StandardError) do
            @gateway.destroy(plan.id, @other_user)
          end

          assert_equal I18n.t('plans.errors.not_found'), error.message
          assert_not_nil ::CultivationPlan.find_by(id: plan.id)
        end

        test "wraps foreign key violations with delete_failed message" do
          plan = create(:cultivation_plan, farm: @farm, user: @user)
          create(:task_schedule, cultivation_plan: plan)

          DeletionUndo::Manager.stub(:schedule, ->(*) { raise ActiveRecord::InvalidForeignKey.new("Cannot delete") }) do
            error = assert_raises(StandardError) do
              @gateway.destroy(plan.id, @user)
            end

            assert_equal I18n.t('plans.errors.delete_failed'), error.message
          end

          assert_not_nil ::CultivationPlan.find_by(id: plan.id)
        end

        test "wraps delete restriction errors with delete_failed message" do
          plan = create(:cultivation_plan, farm: @farm, user: @user)

          DeletionUndo::Manager.stub(:schedule, ->(*) { raise ActiveRecord::DeleteRestrictionError.new("Cannot delete") }) do
            error = assert_raises(StandardError) do
              @gateway.destroy(plan.id, @user)
            end

            assert_equal I18n.t('plans.errors.delete_failed'), error.message
          end

          assert_not_nil ::CultivationPlan.find_by(id: plan.id)
        end

        test "wraps undo scheduling errors with delete_error message" do
          plan = create(:cultivation_plan, farm: @farm, user: @user)
          failure_message = "Undo scheduling failed"

          DeletionUndo::Manager.stub(:schedule, ->(*) { raise DeletionUndo::Error.new(failure_message) }) do
            error = assert_raises(StandardError) do
              @gateway.destroy(plan.id, @user)
            end

            expected_message = I18n.t('plans.errors.delete_error', message: failure_message)
            assert_equal expected_message, error.message
          end

          assert_not_nil ::CultivationPlan.find_by(id: plan.id)
        end
      end
    end
  end
end
