# frozen_string_literal: true

require "test_helper"

class PublicPlanCreatePresenterTest < ActiveSupport::TestCase
  test "on_success calls view.render_response with ok status and plan_id" do
    view_mock = mock
    presenter = Presenters::Api::PublicPlan::PublicPlanCreatePresenter.new(view: view_mock)

    success_dto = Domain::PublicPlan::Dtos::PublicPlanCreateSuccessDto.new(plan_id: 123)

    expected_json = {
      plan_id: 123
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :ok
    )

    presenter.on_success(success_dto)
  end

  test "on_success logs plan_id" do
    view_mock = mock
    presenter = Presenters::Api::PublicPlan::PublicPlanCreatePresenter.new(view: view_mock)

    success_dto = Domain::PublicPlan::Dtos::PublicPlanCreateSuccessDto.new(plan_id: 456)

    view_mock.stubs(:render_response)

    Rails.logger.expects(:info).with(regexp_matches(/PublicPlanCreatePresenter.*Rendering success response with plan_id: 456/))

    presenter.on_success(success_dto)
  end

  test "on_success enqueues job chain when dispatcher is given and view exposes public_plan_optimization_job_instances" do
    dispatcher = mock
    view_mock = mock
    view_mock.stubs(:class).returns(Api::V1::PublicPlans::WizardController)

    presenter = Presenters::Api::PublicPlan::PublicPlanCreatePresenter.new(
      view: view_mock,
      job_chain_async_dispatcher: dispatcher
    )

    success_dto = Domain::PublicPlan::Dtos::PublicPlanCreateSuccessDto.new(plan_id: 789)

    job_instance_mock = mock
    job_instances = [ job_instance_mock ]

    view_mock.expects(:public_plan_optimization_job_instances).with(789).returns(job_instances)
    dispatcher.expects(:enqueue).with(
      job_instances,
      redirect_path: nil,
      caller_label: Api::V1::PublicPlans::WizardController.name
    )

    view_mock.expects(:render_response).with(
      json: { plan_id: 789 },
      status: :ok
    )

    presenter.on_success(success_dto)
  end

  test "on_failure calls view.render_response with not_found status when Farm not found" do
    view_mock = mock
    presenter = Presenters::Api::PublicPlan::PublicPlanCreatePresenter.new(view: view_mock)

    error_dto = Domain::Shared::Dtos::ErrorDto.new("Farm not found")

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
    presenter = Presenters::Api::PublicPlan::PublicPlanCreatePresenter.new(view: view_mock)

    error_dto = Domain::Shared::Dtos::ErrorDto.new("No crops selected")

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
    presenter = Presenters::Api::PublicPlan::PublicPlanCreatePresenter.new(view: view_mock)

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
