# frozen_string_literal: true

require "test_helper"

class PrivatePlanNewPageInteractorTest < ActiveSupport::TestCase
  test "call passes dto from farm_gateway to on_success" do
    user = mock
    user_lookup = mock
    user_lookup.expects(:find).with(9).returns(user)

    farm_gateway = mock
    farm_gateway.expects(:private_plan_new_farm_choices).with(user: user).returns([])

    translator = mock
    translator.expects(:t).with("plans.default_plan_name").returns("D")
    dto = Domain::CultivationPlan::Assemblers::PrivatePlanNewPageAssembler.call(
      farm_choices: [],
      default_plan_name: "D"
    )

    logger = mock

    output = mock
    output.expects(:on_success).with do |actual|
      assert_equal dto.farm_choices, actual.farm_choices
      assert_equal dto.default_plan_name, actual.default_plan_name
      true
    end

    Domain::CultivationPlan::Interactors::PrivatePlanNewPageInteractor.new(
      output_port: output,
      user_id: 9,
      farm_gateway: farm_gateway,
      translator: translator,
      logger: logger,
      user_lookup: user_lookup
    ).call
  end

  test "forwards unexpected errors to on_failure with restart message and logs" do
    user = mock
    user_lookup = mock
    user_lookup.expects(:find).with(9).returns(user)

    farm_gateway = mock
    farm_gateway.expects(:private_plan_new_farm_choices).raises(StandardError.new("db"))

    translator = mock
    translator.expects(:t).with("plans.errors.restart").returns("再開")

    logger = mock
    logger.expects(:error).with do |msg|
      msg.include?("PrivatePlanNewPageInteractor") &&
        msg.include?("db") &&
        msg.include?("/backtrace:")
    end

    output = mock
    output.expects(:on_failure).with do |err|
      assert_equal "再開", err.message
      true
    end

    Domain::CultivationPlan::Interactors::PrivatePlanNewPageInteractor.new(
      output_port: output,
      user_id: 9,
      farm_gateway: farm_gateway,
      translator: translator,
      logger: logger,
      user_lookup: user_lookup
    ).call
  end

  test "re-raises PersistenceFailed after logging" do
    user = mock
    user_lookup = mock
    user_lookup.expects(:find).with(9).returns(user)

    farm_gateway = mock
    farm_gateway.expects(:private_plan_new_farm_choices).raises(
      Domain::Shared::Exceptions::PersistenceFailed.new("db")
    )

    translator = mock
    logger = mock
    logger.expects(:error).with do |msg|
      msg.include?("PrivatePlanNewPageInteractor") &&
        msg.include?("PersistenceFailed") &&
        msg.include?("/backtrace:")
    end

    output = mock
    output.expects(:on_success).never
    output.expects(:on_failure).never

    assert_raises(Domain::Shared::Exceptions::PersistenceFailed) do
      Domain::CultivationPlan::Interactors::PrivatePlanNewPageInteractor.new(
        output_port: output,
        user_id: 9,
        farm_gateway: farm_gateway,
        translator: translator,
        logger: logger,
        user_lookup: user_lookup
      ).call
    end
  end

  test "on_user_lookup_record_not_found calls on_failure with session_invalid and warns" do
    user_lookup = mock
    user_lookup.expects(:find).with(9).raises(Domain::Shared::Exceptions::RecordNotFound.new("missing user"))

    translator = mock
    translator.expects(:t).with("plans.errors.session_invalid").returns("セッション無効")

    logger = mock
    logger.expects(:warn).with(includes("user_record_not_found"))

    farm_gateway = mock
    farm_gateway.expects(:private_plan_new_farm_choices).never

    output = mock
    output.expects(:on_failure).with do |err|
      assert_equal "セッション無効", err.message
      true
    end

    Domain::CultivationPlan::Interactors::PrivatePlanNewPageInteractor.new(
      output_port: output,
      user_id: 9,
      farm_gateway: farm_gateway,
      translator: translator,
      logger: logger,
      user_lookup: user_lookup
    ).call
  end

  test "on_gateway_record_not_found calls on_failure with not_found" do
    user = mock
    user_lookup = mock
    user_lookup.expects(:find).with(9).returns(user)

    farm_gateway = mock
    farm_gateway.expects(:private_plan_new_farm_choices).raises(Domain::Shared::Exceptions::RecordNotFound.new("nf"))

    translator = mock
    translator.expects(:t).with("plans.errors.not_found").returns("見つからない")

    logger = mock
    logger.expects(:warn).with(includes("record_not_found"))

    output = mock
    output.expects(:on_failure).with do |err|
      assert_equal "見つからない", err.message
      true
    end

    Domain::CultivationPlan::Interactors::PrivatePlanNewPageInteractor.new(
      output_port: output,
      user_id: 9,
      farm_gateway: farm_gateway,
      translator: translator,
      logger: logger,
      user_lookup: user_lookup
    ).call
  end

  test "re-raises NoMethodError without on_failure (programming error)" do
    user = mock
    user_lookup = mock
    user_lookup.expects(:find).with(9).returns(user)

    farm_gateway = mock
    farm_gateway.expects(:private_plan_new_farm_choices).raises(NoMethodError.new("bug"))

    translator = mock
    logger = mock
    output = mock
    output.expects(:on_failure).never

    assert_raises(NoMethodError) do
      Domain::CultivationPlan::Interactors::PrivatePlanNewPageInteractor.new(
        output_port: output,
        user_id: 9,
        farm_gateway: farm_gateway,
        translator: translator,
        logger: logger,
        user_lookup: user_lookup
      ).call
    end
  end
end
