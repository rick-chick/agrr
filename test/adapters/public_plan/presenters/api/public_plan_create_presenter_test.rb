# frozen_string_literal: true

require "test_helper"

class PublicPlanCreatePresenterTest < ActiveSupport::TestCase
  test "on_success calls view.render_response with ok status and plan_id" do
    view_mock = mock
    presenter = Adapters::PublicPlan::Presenters::Api::PublicPlanCreatePresenter.new(view: view_mock)

    success_dto = Domain::PublicPlan::Dtos::PublicPlanCreateOutput.new(plan_id: 123)

    expected_json = {
      plan_id: 123
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :ok
    )

    presenter.on_success(success_dto)
  end

  test "on_failure calls view.render_response with not_found status when Farm not found" do
    view_mock = mock
    presenter = Adapters::PublicPlan::Presenters::Api::PublicPlanCreatePresenter.new(view: view_mock)

    error_dto = Domain::Shared::Dtos::Error.new("Farm not found")

    expected_json = {
      error: "Farm not found"
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :not_found
    )

    presenter.on_failure(error_dto)
  end

  test "on_failure calls view.render_response with unprocessable_entity status for validation errors" do
    view_mock = mock
    presenter = Adapters::PublicPlan::Presenters::Api::PublicPlanCreatePresenter.new(view: view_mock)

    error_dto = Domain::Shared::Dtos::Error.new("No crops selected")

    expected_json = {
      error: "No crops selected"
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :unprocessable_entity
    )

    presenter.on_failure(error_dto)
  end

  test "on_failure calls view.render_response with internal_server_error status for unexpected errors" do
    view_mock = mock
    presenter = Adapters::PublicPlan::Presenters::Api::PublicPlanCreatePresenter.new(view: view_mock)

    failure_dto = "Some error string"

    expected_json = {
      error: "Some error string"
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :internal_server_error
    )

    presenter.on_failure(failure_dto)
  end
end
