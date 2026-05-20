# frozen_string_literal: true

require "domain_lib_test_helper"

class PrivatePlanOptimizationRedirectInteractorTest < DomainLibTestCase
  test "call passes dto from gateway to on_success" do
    user = mock
    user_lookup = mock
    user_lookup.expects(:find).with(3).returns(user)

    dto = Domain::CultivationPlan::Dtos::PrivatePlanOptimizationRedirect.new(
      plan_id: 10,
      already_optimizing: false
    )
    gateway = mock
    gateway.expects(:private_plan_optimization_redirect_snapshot).with(user: user, plan_id: 10).returns(dto)

    translator = mock
    logger = mock
    output = mock
    output.expects(:on_success).with do |passed|
      assert_equal 10, passed.plan_id
      assert_equal false, passed.already_optimizing
      true
    end

    Domain::CultivationPlan::Interactors::PrivatePlanOptimizationRedirectInteractor.new(
      output_port: output,
      user_id: 3,
      plan_id: 10,
      gateway: gateway,
      translator: translator,
      logger: logger,
      user_lookup: user_lookup
    ).call
  end

  test "on_user_lookup_record_not_found calls on_failure with session_invalid" do
    user_lookup = mock
    user_lookup.expects(:find).with(3).raises(Domain::Shared::Exceptions::RecordNotFound.new("missing user"))

    translator = mock
    translator.expects(:t).with("plans.errors.session_invalid").returns("セッション無効")

    logger = mock
    logger.expects(:warn).with(includes("user_record_not_found"))

    gateway = mock
    gateway.expects(:private_plan_optimization_redirect_snapshot).never

    output = mock
    output.expects(:on_failure).with do |err|
      assert_equal "セッション無効", err.message
      true
    end

    Domain::CultivationPlan::Interactors::PrivatePlanOptimizationRedirectInteractor.new(
      output_port: output,
      user_id: 3,
      plan_id: 10,
      gateway: gateway,
      translator: translator,
      logger: logger,
      user_lookup: user_lookup
    ).call
  end

  test "on_gateway_record_not_found calls on_failure with not_found" do
    user = mock
    user_lookup = mock
    user_lookup.expects(:find).with(3).returns(user)

    gateway = mock
    gateway.expects(:private_plan_optimization_redirect_snapshot).raises(Domain::Shared::Exceptions::RecordNotFound.new("nf"))

    translator = mock
    translator.expects(:t).with("plans.errors.not_found").returns("見つからない")

    logger = mock
    logger.expects(:warn).with(includes("record_not_found"))

    output = mock
    output.expects(:on_failure).with do |err|
      assert_equal "見つからない", err.message
      true
    end

    Domain::CultivationPlan::Interactors::PrivatePlanOptimizationRedirectInteractor.new(
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
