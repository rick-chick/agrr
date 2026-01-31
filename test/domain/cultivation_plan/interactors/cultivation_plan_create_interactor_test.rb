# frozen_string_literal: true

require "test_helper"

module Domain
  module CultivationPlan
    module Interactors
      class CultivationPlanCreateInteractorTest < ActiveSupport::TestCase
        setup do
          @user = create(:user)
          @mock_gateway = mock
          @mock_output_port = mock
          @interactor = CultivationPlanCreateInteractor.new(
            output_port: @mock_output_port,
            gateway: @mock_gateway
          )
        end

        test "should create cultivation plan successfully" do
          farm = create(:farm, user: @user)
          crop = create(:crop, user: @user, is_reference: false)
          input_dto = Domain::CultivationPlan::Dtos::CultivationPlanCreateInputDto.new(
            farm_id: farm.id,
            plan_name: "Test Plan",
            crop_ids: [crop.id],
            user: @user
          )

          mock_result = mock
          mock_cultivation_plan = mock
          mock_cultivation_plan.stubs(:id).returns(123)
          mock_cultivation_plan.stubs(:display_name).returns("Test Plan")
          mock_cultivation_plan.stubs(:status).returns("optimizing")
          mock_result.stubs(:success?).returns(true)
          mock_result.stubs(:cultivation_plan).returns(mock_cultivation_plan)

          @mock_gateway.expects(:find_farm).with(farm.id, @user).returns(farm)
          @mock_gateway.expects(:find_crops).with([crop.id], @user).returns([crop])
          @mock_gateway.expects(:find_existing).with(farm, @user).returns(nil)
          @mock_gateway.expects(:create).returns(mock_result)

          @mock_output_port.expects(:on_success).with(instance_of(Domain::CultivationPlan::Dtos::CultivationPlanCreateSuccessDto))

          @interactor.call(input_dto)
        end

        test "should fail when farm not found" do
          input_dto = Domain::CultivationPlan::Dtos::CultivationPlanCreateInputDto.new(
            farm_id: 999,
            plan_name: "Test Plan",
            crop_ids: [1],
            user: @user
          )

          @mock_gateway.expects(:find_farm).with(999, @user).returns(nil)
          @mock_output_port.expects(:on_failure).with(instance_of(Domain::Shared::Dtos::ErrorDto))

          @interactor.call(input_dto)
        end

        test "should fail when no valid crops found" do
          farm = create(:farm, user: @user)
          input_dto = Domain::CultivationPlan::Dtos::CultivationPlanCreateInputDto.new(
            farm_id: farm.id,
            plan_name: "Test Plan",
            crop_ids: [999],
            user: @user
          )

          @mock_gateway.expects(:find_farm).with(farm.id, @user).returns(farm)
          @mock_gateway.expects(:find_crops).with([999], @user).returns([])
          @mock_output_port.expects(:on_failure).with(instance_of(Domain::Shared::Dtos::ErrorDto))

          @interactor.call(input_dto)
        end

        test "should fail when existing plan found" do
          farm = create(:farm, user: @user)
          existing_plan = create(:cultivation_plan, farm: farm, user: @user, plan_type: :private)
          input_dto = Domain::CultivationPlan::Dtos::CultivationPlanCreateInputDto.new(
            farm_id: farm.id,
            plan_name: "Test Plan",
            crop_ids: [1],
            user: @user
          )

          @mock_gateway.expects(:find_farm).with(farm.id, @user).returns(farm)
          @mock_gateway.expects(:find_crops).with([1], @user).returns([create(:crop, user: @user, is_reference: false)])
          @mock_gateway.expects(:find_existing).with(farm, @user).returns(existing_plan)
          @mock_output_port.expects(:on_failure).with(instance_of(Domain::Shared::Dtos::ErrorDto))

          @interactor.call(input_dto)
        end

        test "should handle creation failure" do
          farm = create(:farm, user: @user)
          crop = create(:crop, user: @user, is_reference: false)
          input_dto = Domain::CultivationPlan::Dtos::CultivationPlanCreateInputDto.new(
            farm_id: farm.id,
            plan_name: "Test Plan",
            crop_ids: [crop.id],
            user: @user
          )

          mock_result = mock
          mock_result.stubs(:success?).returns(false)

          @mock_gateway.expects(:find_farm).with(farm.id, @user).returns(farm)
          @mock_gateway.expects(:find_crops).with([crop.id], @user).returns([crop])
          @mock_gateway.expects(:find_existing).with(farm, @user).returns(nil)
          @mock_gateway.expects(:create).returns(mock_result)
          @mock_output_port.expects(:on_failure).with(instance_of(Domain::Shared::Dtos::ErrorDto))

          @interactor.call(input_dto)
        end

        test "should handle unexpected errors" do
          farm = create(:farm, user: @user)
          input_dto = Domain::CultivationPlan::Dtos::CultivationPlanCreateInputDto.new(
            farm_id: farm.id,
            plan_name: "Test Plan",
            crop_ids: [1],
            user: @user
          )

          @mock_gateway.expects(:find_farm).with(farm.id, @user).raises(StandardError.new("Database error"))
          @mock_output_port.expects(:on_failure).with(instance_of(Domain::Shared::Dtos::ErrorDto))

          @interactor.call(input_dto)
        end
      end
    end
  end
end