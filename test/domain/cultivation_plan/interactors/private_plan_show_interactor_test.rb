# frozen_string_literal: true

require "domain_lib_test_helper"

class PrivatePlanShowInteractorTest < DomainLibTestCase
  def unused_gantt_clock
    @unused_gantt_clock ||= Object.new.tap { |c| c.define_singleton_method(:today) { Date.new(2001, 1, 1) } }
  end

  test "call passes assembled show dto from gateway detail to on_success" do
    user = mock
    user_lookup = mock
    user_lookup.expects(:find).with(3).returns(user)

    detail = Domain::CultivationPlan::Dtos::PrivateCultivationPlanDetail.new(
      id: 10,
      display_name: "Plan X",
      farm_display_name: "F1",
      total_area: 100,
      field_cultivations_count: 0,
      cultivation_plan_fields_count: 0,
      planning_start_date: Date.new(2025, 6, 1),
      planning_end_date: nil,
      status: "completed",
      field_cultivations: [],
      cultivation_plan_fields: [],
      palette_used_crop_ids: [],
      palette_crops: []
    )

    gateway = mock
    gateway.expects(:find_private_cultivation_plan_detail).with(user: user, plan_id: 10).returns(detail)

    translator = mock
    logger = mock
    output = mock
    output.expects(:on_success).with do |dto|
      assert_instance_of Domain::CultivationPlan::Dtos::PrivatePlanShow, dto
      assert_equal 10, dto.id
      assert_equal "Plan X", dto.display_name
      assert_equal "F1", dto.farm_display_name
      assert_equal 100, dto.total_area
      assert_equal "completed", dto.status
      assert_equal Date.new(2025, 6, 1), dto.planning_start_date
      assert_equal [], dto.gantt_cultivation_rows
      assert_equal [], dto.gantt_field_rows
      true
    end

    Domain::CultivationPlan::Interactors::PrivatePlanShowInteractor.new(
      output_port: output,
      user_id: 3,
      plan_id: 10,
      gateway: gateway,
      translator: translator,
      logger: logger,
      user_lookup: user_lookup,
      clock: unused_gantt_clock
    ).call
  end

  test "call fills nil planning_start_date from clock before on_success" do
    user = mock
    user_lookup = mock
    user_lookup.expects(:find).with(3).returns(user)

    detail = Domain::CultivationPlan::Dtos::PrivateCultivationPlanDetail.new(
      id: 10,
      display_name: "Plan X",
      farm_display_name: "F1",
      total_area: 100,
      field_cultivations_count: 0,
      cultivation_plan_fields_count: 0,
      planning_start_date: nil,
      planning_end_date: nil,
      status: "completed",
      field_cultivations: [],
      cultivation_plan_fields: [],
      palette_used_crop_ids: [],
      palette_crops: []
    )

    gateway = mock
    gateway.expects(:find_private_cultivation_plan_detail).with(user: user, plan_id: 10).returns(detail)

    translator = mock
    logger = mock
    fallback = Date.new(2026, 4, 1)
    clock = Object.new
    clock.define_singleton_method(:today) { fallback }

    output = mock
    output.expects(:on_success).with do |dto|
      assert_equal fallback, dto.planning_start_date
      assert_equal 10, dto.id
      true
    end

    Domain::CultivationPlan::Interactors::PrivatePlanShowInteractor.new(
      output_port: output,
      user_id: 3,
      plan_id: 10,
      gateway: gateway,
      translator: translator,
      logger: logger,
      user_lookup: user_lookup,
      clock: clock
    ).call
  end

  test "on_user_lookup_record_not_found calls on_failure with session_invalid and warns" do
    user_lookup = mock
    user_lookup.expects(:find).with(3).raises(Domain::Shared::Exceptions::RecordNotFound.new("missing user"))

    translator = mock
    translator.expects(:t).with("plans.errors.session_invalid").returns("セッション無効")

    logger = mock
    logger.expects(:warn).with(includes("user_record_not_found"))

    gateway = mock
    gateway.expects(:find_private_cultivation_plan_detail).never

    output = mock
    output.expects(:on_failure).with do |err|
      assert_equal "セッション無効", err.message
      true
    end

    Domain::CultivationPlan::Interactors::PrivatePlanShowInteractor.new(
      output_port: output,
      user_id: 3,
      plan_id: 10,
      gateway: gateway,
      translator: translator,
      logger: logger,
      user_lookup: user_lookup,
      clock: unused_gantt_clock
    ).call
  end

  test "on_gateway_record_not_found calls on_failure with not_found" do
    user = mock
    user_lookup = mock
    user_lookup.expects(:find).with(3).returns(user)

    gateway = mock
    gateway.expects(:find_private_cultivation_plan_detail).raises(Domain::Shared::Exceptions::RecordNotFound.new("nf"))

    translator = mock
    translator.expects(:t).with("plans.errors.not_found").returns("見つからない")

    logger = mock
    logger.expects(:warn).with(includes("record_not_found"))

    output = mock
    output.expects(:on_failure).with do |err|
      assert_equal "見つからない", err.message
      true
    end

    Domain::CultivationPlan::Interactors::PrivatePlanShowInteractor.new(
      output_port: output,
      user_id: 3,
      plan_id: 10,
      gateway: gateway,
      translator: translator,
      logger: logger,
      user_lookup: user_lookup,
      clock: unused_gantt_clock
    ).call
  end

  test "propagates unexpected StandardError from gateway" do
    user = mock
    user_lookup = mock
    user_lookup.expects(:find).with(3).returns(user)

    gateway = mock
    gateway.expects(:find_private_cultivation_plan_detail).raises(StandardError.new("internal"))

    translator = mock
    logger = mock
    output = mock
    output.expects(:on_failure).never

    err = assert_raises(StandardError) do
      Domain::CultivationPlan::Interactors::PrivatePlanShowInteractor.new(
        output_port: output,
        user_id: 3,
        plan_id: 10,
        gateway: gateway,
        translator: translator,
        logger: logger,
        user_lookup: user_lookup,
        clock: unused_gantt_clock
      ).call
    end
    assert_equal "internal", err.message
  end

  test "re-raises PersistenceFailed after logging" do
    user = mock
    user_lookup = mock
    user_lookup.expects(:find).with(3).returns(user)

    gateway = mock
    gateway.expects(:find_private_cultivation_plan_detail).raises(
      Domain::Shared::Exceptions::PersistenceFailed.new("db")
    )

    translator = mock
    logger = mock
    logger.expects(:error).with do |msg|
      msg.include?("PrivatePlanShowInteractor") &&
        msg.include?("PersistenceFailed") &&
        msg.include?("/backtrace:")
    end

    output = mock
    output.expects(:on_success).never
    output.expects(:on_failure).never

    assert_raises(Domain::Shared::Exceptions::PersistenceFailed) do
      Domain::CultivationPlan::Interactors::PrivatePlanShowInteractor.new(
        output_port: output,
        user_id: 3,
        plan_id: 10,
        gateway: gateway,
        translator: translator,
        logger: logger,
        user_lookup: user_lookup,
        clock: unused_gantt_clock
      ).call
    end
  end

  test "re-raises NoMethodError without on_failure (programming error)" do
    user = mock
    user_lookup = mock
    user_lookup.expects(:find).with(3).returns(user)

    gateway = mock
    gateway.expects(:find_private_cultivation_plan_detail).raises(NoMethodError.new("bug"))

    translator = mock
    logger = mock
    output = mock
    output.expects(:on_failure).never

    assert_raises(NoMethodError) do
      Domain::CultivationPlan::Interactors::PrivatePlanShowInteractor.new(
        output_port: output,
        user_id: 3,
        plan_id: 10,
        gateway: gateway,
        translator: translator,
        logger: logger,
        user_lookup: user_lookup,
        clock: unused_gantt_clock
      ).call
    end
  end
end
