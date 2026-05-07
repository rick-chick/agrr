# frozen_string_literal: true

require "test_helper"

class PublicPlanOptimizingHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test "on_success sets @public_plan_optimizing from dto when status is optimizing" do
    view_mock = mock
    dto = Domain::CultivationPlan::Dtos::PublicPlanOptimizingDto.new(
      id: 1,
      plan_year: 2025,
      farm_display_name: "Farm",
      cultivation_plan_crops_count: 3,
      optimization_phase_message: nil,
      status: "optimizing"
    )
    view_mock.expects(:instance_variable_set).with(:@public_plan_optimizing, dto)

    presenter = Presenters::Html::PublicPlans::PublicPlanOptimizingHtmlPresenter.new(view: view_mock)
    presenter.on_success(dto)
  end

  test "on_success redirects to public_plans_results_path when completed" do
    view_mock = mock
    dto = Domain::CultivationPlan::Dtos::PublicPlanOptimizingDto.new(
      id: 99,
      plan_year: 2025,
      farm_display_name: "Farm",
      cultivation_plan_crops_count: 3,
      optimization_phase_message: nil,
      status: "completed"
    )
    view_mock.expects(:public_plans_results_path).returns("/public_plans/results")
    view_mock.expects(:redirect_to).with("/public_plans/results")

    presenter = Presenters::Html::PublicPlans::PublicPlanOptimizingHtmlPresenter.new(view: view_mock)
    presenter.on_success(dto)
  end

  test "on_success redirects to public_plans_results_path with alert when failed" do
    view_mock = mock
    dto = Domain::CultivationPlan::Dtos::PublicPlanOptimizingDto.new(
      id: 8,
      plan_year: 2025,
      farm_display_name: "Farm",
      cultivation_plan_crops_count: 3,
      optimization_phase_message: nil,
      status: "failed"
    )
    view_mock.expects(:public_plans_results_path).returns("/public_plans/results")
    view_mock.expects(:redirect_to).with(
      "/public_plans/results",
      alert: I18n.t("public_plans.optimizing.error.title")
    )

    presenter = Presenters::Html::PublicPlans::PublicPlanOptimizingHtmlPresenter.new(view: view_mock)
    presenter.on_success(dto)
  end

  test "on_failure redirects to public_plans_path with alert" do
    view_mock = mock
    err = mock
    err.expects(:respond_to?).with(:message).returns(true)
    err.expects(:message).returns("bad")
    view_mock.expects(:public_plans_path).returns("/public_plans")
    view_mock.expects(:redirect_to).with("/public_plans", alert: "bad")

    presenter = Presenters::Html::PublicPlans::PublicPlanOptimizingHtmlPresenter.new(view: view_mock)
    presenter.on_failure(err)
  end
end
