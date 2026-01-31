# frozen_string_literal: true

require 'test_helper'

class CultivationPlanCreatePresenterTest < ActiveSupport::TestCase
  test 'on_success calls view.render_response with created status and serialized success data' do
    view_mock = mock
    presenter = Api::CultivationPlan::CultivationPlanCreatePresenter.new(view: view_mock)

    success_dto = Domain::CultivationPlan::Dtos::CultivationPlanCreateSuccessDto.new(
      id: 123,
      name: 'Test Plan',
      status: 'optimizing'
    )

    expected_json = {
      id: 123,
      name: 'Test Plan',
      status: 'optimizing'
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :created
    )

    presenter.on_success(success_dto)
  end

  test 'on_failure calls view.render_response with unprocessable_entity status and error message' do
    view_mock = mock
    presenter = Api::CultivationPlan::CultivationPlanCreatePresenter.new(view: view_mock)

    error_dto = Domain::Shared::Dtos::ErrorDto.new('Plan already exists for this farm')

    expected_json = {
      error: 'Plan already exists for this farm'
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :unprocessable_entity
    )

    presenter.on_failure(error_dto)
  end

  test 'on_failure handles non-ErrorDto failure objects' do
    view_mock = mock
    presenter = Api::CultivationPlan::CultivationPlanCreatePresenter.new(view: view_mock)

    failure_dto = 'Some error string'

    expected_json = {
      error: 'Some error string'
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :unprocessable_entity
    )

    presenter.on_failure(failure_dto)
  end
end