# frozen_string_literal: true

require "test_helper"

class PrivatePlanOptimizingHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test "on_success sets @private_plan_optimizing_page from dto" do
    view_mock = mock
    dto = Domain::CultivationPlan::Dtos::PrivatePlanOptimizingPageDto.new(
      id: 1,
      plan_year: 2025,
      farm_display_name: "Farm",
      cultivation_plan_crops_count: 3,
      optimization_phase_message: nil,
      status: "optimizing"
    )
    view_mock.expects(:instance_variable_set).with(:@private_plan_optimizing_page, dto)

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
