# frozen_string_literal: true

require "test_helper"

class PrivatePlanOptimizingInteractorTest < ActiveSupport::TestCase
  test "call passes dto from gateway to on_success" do
    user = mock
    user_lookup = mock
    user_lookup.expects(:find).with(3).returns(user)

    read_model = Domain::CultivationPlan::Dtos::PrivatePlanOptimizingReadModel.new(
      id: 10,
      plan_year: 2025,
      farm_display_name: "F1",
      cultivation_plan_crops_count: 2,
      optimization_phase_message: "msg",
      status: "optimizing"
    )
    dto = Domain::CultivationPlan::Assemblers::PrivatePlanOptimizingAssembler.call(read_model)

    gateway = mock
    gateway.expects(:private_plan_optimizing_read_model).with(plan_id: 10, user: user).returns(read_model)

    translator = mock
    logger = mock
    output = mock
    output.expects(:on_success).with do |actual|
      assert_equal dto.id, actual.id
      assert_equal dto.plan_year, actual.plan_year
      assert_equal dto.farm_display_name, actual.farm_display_name
      assert_equal dto.cultivation_plan_crops_count, actual.cultivation_plan_crops_count
      assert_equal dto.optimization_phase_message, actual.optimization_phase_message
      assert_equal dto.status, actual.status
      true
    end

    Domain::CultivationPlan::Interactors::PrivatePlanOptimizingInteractor.new(
      output_port: output,
      user_id: 3,
      plan_id: 10,
      gateway: gateway,
      translator: translator,
      logger: logger,
      user_lookup: user_lookup
    ).call
  end

  test "call forwards PolicyPermissionDenied to on_failure with not_found message" do
    user = mock
    user_lookup = mock
    user_lookup.expects(:find).with(3).returns(user)

    gateway = mock
    gateway.expects(:private_plan_optimizing_read_model).raises(PolicyPermissionDenied)

    translator = mock
    translator.expects(:t).with("plans.errors.not_found").returns("見つかりません")

    logger = mock

    output = mock
    output.expects(:on_failure).with do |err|
      assert_equal "見つかりません", err.message
      true
    end

    Domain::CultivationPlan::Interactors::PrivatePlanOptimizingInteractor.new(
      output_port: output,
      user_id: 3,
      plan_id: 10,
      gateway: gateway,
      translator: translator,
      logger: logger,
      user_lookup: user_lookup
    ).call
  end

  test "call forwards RecordNotFound to on_failure with not_found message" do
    user = mock
    user_lookup = mock
    user_lookup.expects(:find).with(3).returns(user)

    gateway = mock
    gateway.expects(:private_plan_optimizing_read_model).raises(Domain::Shared::Exceptions::RecordNotFound.new("x"))

    translator = mock
    translator.expects(:t).with("plans.errors.not_found").returns("見つかりません")

    logger = mock

    output = mock
    output.expects(:on_failure).with do |err|
      assert_equal "見つかりません", err.message
      true
    end

    Domain::CultivationPlan::Interactors::PrivatePlanOptimizingInteractor.new(
      output_port: output,
      user_id: 3,
      plan_id: 10,
      gateway: gateway,
      translator: translator,
      logger: logger,
      user_lookup: user_lookup
    ).call
  end

  test "propagates unexpected StandardError from gateway" do
    user = mock
    user_lookup = mock
    user_lookup.expects(:find).with(3).returns(user)

    gateway = mock
    gateway.expects(:private_plan_optimizing_read_model).raises(StandardError.new("internal"))

    translator = mock
    logger = mock
    output = mock
    output.expects(:on_failure).never

    err = assert_raises(StandardError) do
      Domain::CultivationPlan::Interactors::PrivatePlanOptimizingInteractor.new(
        output_port: output,
        user_id: 3,
        plan_id: 10,
        gateway: gateway,
        translator: translator,
        logger: logger,
        user_lookup: user_lookup
      ).call
    end
    assert_equal "internal", err.message
  end
end
