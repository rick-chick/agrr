# frozen_string_literal: true

require "test_helper"

class PrivatePlanIndexHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test "on_success sets @private_plan_index_page" do
    view_mock = mock
    dto = Domain::CultivationPlan::Dtos::PrivatePlanIndexPageDto.new(plan_rows: [])
    view_mock.expects(:instance_variable_set).with(:@private_plan_index_page, dto)

    presenter = Presenters::Html::Plans::PrivatePlanIndexHtmlPresenter.new(view: view_mock)
    presenter.on_success(dto)
  end

  test "on_failure redirects to plans_path with alert" do
    view_mock = mock
    err = mock
    err.expects(:respond_to?).with(:message).returns(true)
    err.expects(:message).returns("x")
    view_mock.expects(:plans_path).returns("/plans")
    view_mock.expects(:redirect_to).with("/plans", alert: "x")

    presenter = Presenters::Html::Plans::PrivatePlanIndexHtmlPresenter.new(view: view_mock)
    presenter.on_failure(err)
  end
end
