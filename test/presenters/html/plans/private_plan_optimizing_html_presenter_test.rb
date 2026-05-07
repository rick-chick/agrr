# frozen_string_literal: true

require "test_helper"

class PrivatePlanOptimizingHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test "on_success sets @private_plan_optimizing from dto when status is optimizing" do
    view_mock = mock
    dto = Domain::CultivationPlan::Dtos::PrivatePlanOptimizingDto.new(
      id: 1,
      plan_year: 2025,
      farm_display_name: "Farm",
      cultivation_plan_crops_count: 3,
      optimization_phase_message: nil,
      status: "optimizing"
    )
    view_mock.expects(:instance_variable_set).with(:@private_plan_optimizing, dto)

    presenter = Presenters::Html::Plans::PrivatePlanOptimizingHtmlPresenter.new(view: view_mock)
    presenter.on_success(dto)
  end

  test "on_success redirects to plan_path when completed" do
    view_mock = mock
    dto = Domain::CultivationPlan::Dtos::PrivatePlanOptimizingDto.new(
      id: 42,
      plan_year: 2025,
      farm_display_name: "Farm",
      cultivation_plan_crops_count: 3,
      optimization_phase_message: nil,
      status: "completed"
    )
    view_mock.expects(:plan_path).with(42).returns("/plans/42")
    view_mock.expects(:redirect_to).with("/plans/42")

    presenter = Presenters::Html::Plans::PrivatePlanOptimizingHtmlPresenter.new(view: view_mock)
    presenter.on_success(dto)
  end

  test "on_success redirects to plan_path with alert when failed" do
    view_mock = mock
    dto = Domain::CultivationPlan::Dtos::PrivatePlanOptimizingDto.new(
      id: 7,
      plan_year: 2025,
      farm_display_name: "Farm",
      cultivation_plan_crops_count: 3,
      optimization_phase_message: nil,
      status: "failed"
    )
    view_mock.expects(:plan_path).with(7).returns("/plans/7")
    view_mock.expects(:redirect_to).with(
      "/plans/7",
      alert: I18n.t("plans.optimizing.error.title")
    )

    presenter = Presenters::Html::Plans::PrivatePlanOptimizingHtmlPresenter.new(view: view_mock)
    presenter.on_success(dto)
  end

  test "on_failure redirects to plans_path with alert" do
    view_mock = mock
    err = mock
    err.expects(:respond_to?).with(:message).returns(true)
    err.expects(:message).returns("bad")
    view_mock.expects(:plans_path).returns("/plans")
    view_mock.expects(:redirect_to).with("/plans", alert: "bad")

    presenter = Presenters::Html::Plans::PrivatePlanOptimizingHtmlPresenter.new(view: view_mock)
    presenter.on_failure(err)
  end
end
