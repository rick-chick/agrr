# frozen_string_literal: true

require 'test_helper'

# Load the presenter class
require_relative '../../../../app/presenters/api/crop/nutrient_requirement_update_presenter'

class NutrientRequirementUpdatePresenterTest < ActiveSupport::TestCase
  test 'on_success calls view.render_response with ok status and serialized success data' do
    view_mock = mock
    presenter = Api::Crop::NutrientRequirementUpdatePresenter.new(view: view_mock)

    requirement_mock = mock
    requirement_mock.expects(:id).returns(123)
    requirement_mock.expects(:crop_stage_id).returns(456)
    requirement_mock.expects(:daily_uptake_n).returns(2.5)
    requirement_mock.expects(:daily_uptake_p).returns(0.8)
    requirement_mock.expects(:daily_uptake_k).returns(3.2)
    requirement_mock.expects(:region).returns('Japan')

    success_dto = Domain::Crop::Dtos::NutrientRequirementOutputDto.new(requirement: requirement_mock)

    expected_json = {
      id: 123,
      crop_stage_id: 456,
      daily_uptake_n: 2.5,
      daily_uptake_p: 0.8,
      daily_uptake_k: 3.2,
      region: 'Japan'
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :ok
    )

    presenter.on_success(success_dto)
  end

  test 'on_failure calls view.render_response with unprocessable_entity status and error message' do
    view_mock = mock
    presenter = Api::Crop::NutrientRequirementUpdatePresenter.new(view: view_mock)

    error_dto = Domain::Shared::Dtos::ErrorDto.new('Nutrient requirement update failed')

    expected_json = {
      error: 'Nutrient requirement update failed'
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :unprocessable_entity
    )

    presenter.on_failure(error_dto)
  end

  test 'on_failure handles non-ErrorDto failure objects' do
    view_mock = mock
    presenter = Api::Crop::NutrientRequirementUpdatePresenter.new(view: view_mock)

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