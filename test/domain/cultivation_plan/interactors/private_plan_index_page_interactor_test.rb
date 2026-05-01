# frozen_string_literal: true

require "test_helper"

class PrivatePlanIndexPageInteractorTest < ActiveSupport::TestCase
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
    dto = Domain::CultivationPlan::Dtos::PrivatePlanIndexPageDto.new(plan_rows: [ row ])

    gateway = mock
    gateway.expects(:private_plan_index_page).with(user: user).returns(dto)

    translator = mock
    logger = mock

    output = mock
    output.expects(:on_success).with(dto)

    Domain::CultivationPlan::Interactors::PrivatePlanIndexPageInteractor.new(
      output_port: output,
      user_id: 9,
      gateway: gateway,
      translator: translator,
      logger: logger,
      user_lookup: user_lookup
    ).call
  end

  test "forwards unexpected errors to on_failure with restart message and logs" do
    user = mock
    user_lookup = mock
    user_lookup.expects(:find).with(9).returns(user)

    gateway = mock
    gateway.expects(:private_plan_index_page).raises(StandardError.new("db"))

    translator = mock
    translator.expects(:t).with("plans.errors.restart").returns("再開")

    logger = mock
    logger.expects(:error).with(includes("PrivatePlanIndexPageInteractor"))

    output = mock
    output.expects(:on_failure).with do |err|
      assert_equal "再開", err.message
      true
    end

    Domain::CultivationPlan::Interactors::PrivatePlanIndexPageInteractor.new(
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
    gateway.expects(:private_plan_index_page).raises(NoMethodError.new("bug"))

    translator = mock
    logger = mock
    output = mock
    output.expects(:on_failure).never

    assert_raises(NoMethodError) do
      Domain::CultivationPlan::Interactors::PrivatePlanIndexPageInteractor.new(
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
