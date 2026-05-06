# frozen_string_literal: true

require "test_helper"

class PublicPlanOptimizingInteractorTest < ActiveSupport::TestCase
  test "call passes dto from gateway to on_success" do
    read_model = Domain::CultivationPlan::Dtos::PublicPlanOptimizingReadModel.new(
      id: 10,
      plan_year: nil,
      farm_display_name: "F1",
      cultivation_plan_crops_count: 2,
      optimization_phase_message: "msg",
      status: "optimizing"
    )

    gateway = mock
    gateway.expects(:public_plan_optimizing_read_model).with(plan_id: 10).returns(read_model)

    translator = mock
    logger = mock

    output = mock
    output.expects(:on_success).with do |actual|
      assert_equal 10, actual.id
      assert_nil actual.plan_year
      assert_equal "F1", actual.farm_display_name
      assert_equal 2, actual.cultivation_plan_crops_count
      assert_equal "msg", actual.optimization_phase_message
      assert_equal "optimizing", actual.status
      true
    end

    Domain::CultivationPlan::Interactors::PublicPlanOptimizingInteractor.new(
      output_port: output,
      plan_id: 10,
      gateway: gateway,
      translator: translator,
      logger: logger
    ).call
  end

  test "call forwards missing plan_id to on_failure" do
    gateway = mock
    gateway.expects(:public_plan_optimizing_read_model).never

    translator = mock
    translator.expects(:t).with("public_plans.errors.not_found").returns("見つかりません")

    logger = mock

    output = mock
    output.expects(:on_failure).with do |err|
      assert_equal "見つかりません", err.message
      true
    end

    Domain::CultivationPlan::Interactors::PublicPlanOptimizingInteractor.new(
      output_port: output,
      plan_id: nil,
      gateway: gateway,
      translator: translator,
      logger: logger
    ).call
  end

  test "call forwards RecordNotFound to on_failure with not_found message" do
    gateway = mock
    gateway.expects(:public_plan_optimizing_read_model).raises(Domain::Shared::Exceptions::RecordNotFound.new("x"))

    translator = mock
    translator.expects(:t).with("public_plans.errors.not_found").returns("見つかりません")

    logger = mock

    output = mock
    output.expects(:on_failure).with do |err|
      assert_equal "見つかりません", err.message
      true
    end

    Domain::CultivationPlan::Interactors::PublicPlanOptimizingInteractor.new(
      output_port: output,
      plan_id: 10,
      gateway: gateway,
      translator: translator,
      logger: logger
    ).call
  end

  test "propagates unexpected StandardError from gateway" do
    gateway = mock
    gateway.expects(:public_plan_optimizing_read_model).raises(StandardError.new("internal"))

    translator = mock
    logger = mock
    output = mock
    output.expects(:on_failure).never

    assert_raises(StandardError) do
      Domain::CultivationPlan::Interactors::PublicPlanOptimizingInteractor.new(
        output_port: output,
        plan_id: 10,
        gateway: gateway,
        translator: translator,
        logger: logger
      ).call
    end
  end
end
