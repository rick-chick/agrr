# frozen_string_literal: true

require "test_helper"

class PrivatePlanShowHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test "on_success sets @private_plan_show from dto" do
    view_mock = mock
    dto = Domain::CultivationPlan::Dtos::PrivatePlanShowDto.new(
      id: 1,
      display_name: "Plan",
      farm_display_name: "Farm",
      total_area: 10,
      field_cultivations_count: 0,
      cultivation_plan_fields_count: 0,
      planning_start_date: nil,
      planning_end_date: nil,
      status: "completed",
      gantt_cultivation_rows: [],
      gantt_field_rows: [],
      palette_used_crop_ids: [],
      palette_crops: []
    )
    view_mock.expects(:instance_variable_set).with(:@private_plan_show, dto)

    presenter = Presenters::Html::Plans::PrivatePlanShowHtmlPresenter.new(view: view_mock)
    presenter.on_success(dto)
  end

  test "on_failure redirects to plans_path with alert" do
    view_mock = mock
    err = mock
    err.expects(:respond_to?).with(:message).returns(true)
    err.expects(:message).returns("bad")
    view_mock.expects(:plans_path).returns("/plans")
    view_mock.expects(:redirect_to).with("/plans", alert: "bad")

    presenter = Presenters::Html::Plans::PrivatePlanShowHtmlPresenter.new(view: view_mock)
    presenter.on_failure(err)
  end
end
