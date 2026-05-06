# frozen_string_literal: true

require "test_helper"

class PrivatePlanIndexInteractorTest < ActiveSupport::TestCase
  test "call passes dto from gateway to on_success" do
    user = mock
    user_lookup = mock
    user_lookup.expects(:find).with(9).returns(user)

    row = Domain::CultivationPlan::Dtos::PrivatePlanIndexPlanRowDto.new(
      id: 1,
      farm_display_name: "F",
      total_area: 100,
      crops_count: 2,
      fields_count: 1,
      status: "pending",
      display_name: "Plan",
      created_at: Time.zone.parse("2026-01-01 12:00:00")
    )
    dto = Domain::CultivationPlan::Assemblers::PrivatePlanIndexAssembler.call(plan_rows: [ row ])

    gateway = mock
    gateway.expects(:private_plan_index_plan_rows).with(user: user).returns([ row ])

    translator = mock
    logger = mock

    output = mock
    output.expects(:on_success).with do |actual|
      assert_equal dto.plan_rows, actual.plan_rows
      true
    end

    Domain::CultivationPlan::Interactors::PrivatePlanIndexInteractor.new(
      output_port: output,
      user_id: 9,
      gateway: gateway,
      translator: translator,
      logger: logger,
      user_lookup: user_lookup
    ).call
  end

  test "propagates unexpected StandardError from gateway" do
    user = mock
    user_lookup = mock
    user_lookup.expects(:find).with(9).returns(user)

    gateway = mock
    gateway.expects(:private_plan_index_plan_rows).raises(StandardError.new("db"))

    translator = mock
    logger = mock
    output = mock
    output.expects(:on_failure).never

    err = assert_raises(StandardError) do
      Domain::CultivationPlan::Interactors::PrivatePlanIndexInteractor.new(
        output_port: output,
        user_id: 9,
        gateway: gateway,
        translator: translator,
        logger: logger,
        user_lookup: user_lookup
      ).call
    end
    assert_equal "db", err.message
  end

  test "re-raises PersistenceFailed after logging" do
    user = mock
    user_lookup = mock
    user_lookup.expects(:find).with(9).returns(user)

    gateway = mock
    gateway.expects(:private_plan_index_plan_rows).raises(
      Domain::Shared::Exceptions::PersistenceFailed.new("db")
    )

    translator = mock
    logger = mock
    logger.expects(:error).with do |msg|
      msg.include?("PrivatePlanIndexInteractor") &&
        msg.include?("PersistenceFailed") &&
        msg.include?("/backtrace:")
    end

    output = mock
    output.expects(:on_success).never
    output.expects(:on_failure).never

    assert_raises(Domain::Shared::Exceptions::PersistenceFailed) do
      Domain::CultivationPlan::Interactors::PrivatePlanIndexInteractor.new(
        output_port: output,
        user_id: 9,
        gateway: gateway,
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

    gateway = mock
    gateway.expects(:private_plan_index_plan_rows).never

    output = mock
    output.expects(:on_failure).with do |err|
      assert_equal "セッション無効", err.message
      true
    end

    Domain::CultivationPlan::Interactors::PrivatePlanIndexInteractor.new(
      output_port: output,
      user_id: 9,
      gateway: gateway,
      translator: translator,
      logger: logger,
      user_lookup: user_lookup
    ).call
  end

  test "on_gateway_record_not_found calls on_failure with not_found" do
    user = mock
    user_lookup = mock
    user_lookup.expects(:find).with(9).returns(user)

    gateway = mock
    gateway.expects(:private_plan_index_plan_rows).raises(Domain::Shared::Exceptions::RecordNotFound.new("nf"))

    translator = mock
    translator.expects(:t).with("plans.errors.not_found").returns("見つからない")

    logger = mock
    logger.expects(:warn).with(includes("record_not_found"))

    output = mock
    output.expects(:on_failure).with do |err|
      assert_equal "見つからない", err.message
      true
    end

    Domain::CultivationPlan::Interactors::PrivatePlanIndexInteractor.new(
      output_port: output,
      user_id: 9,
      gateway: gateway,
      translator: translator,
      logger: logger,
      user_lookup: user_lookup
    ).call
  end

  test "re-raises NoMethodError without on_failure (programming error)" do
    user = mock
    user_lookup = mock
    user_lookup.expects(:find).with(9).returns(user)

    gateway = mock
    gateway.expects(:private_plan_index_plan_rows).raises(NoMethodError.new("bug"))

    translator = mock
    logger = mock
    output = mock
    output.expects(:on_failure).never

    assert_raises(NoMethodError) do
      Domain::CultivationPlan::Interactors::PrivatePlanIndexInteractor.new(
        output_port: output,
        user_id: 9,
        gateway: gateway,
        translator: translator,
        logger: logger,
        user_lookup: user_lookup
      ).call
    end
  end
end
