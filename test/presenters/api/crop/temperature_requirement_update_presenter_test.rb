# frozen_string_literal: true

require 'test_helper'

# Load the presenter class
require_relative '../../../../app/presenters/api/crop/temperature_requirement_update_presenter'

class TemperatureRequirementUpdatePresenterTest < ActiveSupport::TestCase
  test 'on_success calls view.render_response with ok status and serialized success data' do
    view_mock = mock
    presenter = Api::Crop::TemperatureRequirementUpdatePresenter.new(view: view_mock)

    requirement_mock = mock
    requirement_mock.expects(:id).returns(123)
    requirement_mock.expects(:crop_stage_id).returns(456)
    requirement_mock.expects(:base_temperature).returns(15.0)
    requirement_mock.expects(:optimal_min).returns(20.0)
    requirement_mock.expects(:optimal_max).returns(30.0)
    requirement_mock.expects(:low_stress_threshold).returns(10.0)
    requirement_mock.expects(:high_stress_threshold).returns(35.0)
    requirement_mock.expects(:frost_threshold).returns(0.0)
    requirement_mock.expects(:sterility_risk_threshold).returns(40.0)
    requirement_mock.expects(:max_temperature).returns(45.0)

    success_dto = Domain::Crop::Dtos::TemperatureRequirementOutputDto.new(requirement: requirement_mock)

    expected_json = {
      id: 123,
      crop_stage_id: 456,
      base_temperature: 15.0,
      optimal_min: 20.0,
      optimal_max: 30.0,
      low_stress_threshold: 10.0,
      high_stress_threshold: 35.0,
      frost_threshold: 0.0,
      sterility_risk_threshold: 40.0,
      max_temperature: 45.0
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :ok
    )

    presenter.on_success(success_dto)
  end

  test 'on_failure calls view.render_response with unprocessable_entity status and error message' do
    view_mock = mock
    presenter = Api::Crop::TemperatureRequirementUpdatePresenter.new(view: view_mock)

    error_dto = Domain::Shared::Dtos::ErrorDto.new('Temperature requirement update failed')

    expected_json = {
      error: 'Temperature requirement update failed'
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :unprocessable_entity
    )

    presenter.on_failure(error_dto)
  end

  test 'on_failure handles non-ErrorDto failure objects' do
    view_mock = mock
    presenter = Api::Crop::TemperatureRequirementUpdatePresenter.new(view: view_mock)

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