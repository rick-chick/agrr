# frozen_string_literal: true

require "test_helper"

class PrivatePlanOptimizingPageInteractorTest < ActiveSupport::TestCase
  test "call passes dto from gateway to on_success" do
    user = mock
    user_lookup = mock
    user_lookup.expects(:find).with(3).returns(user)

    dto = Domain::CultivationPlan::Dtos::PrivatePlanOptimizingPageDto.new(
      id: 10,
      plan_year: 2025,
      farm_display_name: "F1",
      cultivation_plan_crops_count: 2,
      optimization_phase_message: "msg",
      status: "optimizing"
    )

    gateway = mock
    gateway.expects(:private_plan_optimizing_page_context).with(plan_id: 10, user: user).returns(dto)

    translator = mock
    logger = mock
    output = mock
    output.expects(:on_success).with(dto)

    Domain::CultivationPlan::Interactors::PrivatePlanOptimizingPageInteractor.new(
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
    gateway.expects(:private_plan_optimizing_page_context).raises(PolicyPermissionDenied)

    translator = mock
    translator.expects(:t).with("plans.errors.not_found").returns("見つかりません")

    logger = mock

    output = mock
    output.expects(:on_failure).with do |err|
      assert_equal "見つかりません", err.message
      true
    end

    Domain::CultivationPlan::Interactors::PrivatePlanOptimizingPageInteractor.new(
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
    gateway.expects(:private_plan_optimizing_page_context).raises(Domain::Shared::Exceptions::RecordNotFound.new("x"))

    translator = mock
    translator.expects(:t).with("plans.errors.not_found").returns("見つかりません")

    logger = mock

    output = mock
    output.expects(:on_failure).with do |err|
      assert_equal "見つかりません", err.message
      true
    end

    Domain::CultivationPlan::Interactors::PrivatePlanOptimizingPageInteractor.new(
      output_port: output,
      user_id: 3,
      plan_id: 10,
      gateway: gateway,
      translator: translator,
      logger: logger,
      user_lookup: user_lookup
    ).call
  end

  test "logs and forwards unexpected error to on_failure with restart message" do
    user = mock
    user_lookup = mock
    user_lookup.expects(:find).with(3).returns(user)

    gateway = mock
    gateway.expects(:private_plan_optimizing_page_context).raises(StandardError.new("internal"))

    translator = mock
    translator.expects(:t).with("plans.errors.restart").returns("やり直し")

    logger = mock
    logger.expects(:error).with(includes("PrivatePlanOptimizingPageInteractor"))

    output = mock
    output.expects(:on_failure).with do |err|
      assert_equal "やり直し", err.message
      true
    end

    Domain::CultivationPlan::Interactors::PrivatePlanOptimizingPageInteractor.new(
      output_port: output,
      user_id: 3,
      plan_id: 10,
      gateway: gateway,
      translator: translator,
      logger: logger,
      user_lookup: user_lookup
    ).call
  end
end
