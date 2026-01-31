# frozen_string_literal: true

require 'test_helper'

# Load the presenter class
require_relative '../../../../app/presenters/api/crop/thermal_requirement_update_presenter'

class ThermalRequirementUpdatePresenterTest < ActiveSupport::TestCase
  test 'on_success calls view.render_response with ok status and serialized success data' do
    view_mock = mock
    presenter = Api::Crop::ThermalRequirementUpdatePresenter.new(view: view_mock)

    requirement_mock = mock
    requirement_mock.expects(:id).returns(123)
    requirement_mock.expects(:crop_stage_id).returns(456)
    requirement_mock.expects(:required_gdd).returns(1200.0)

    success_dto = Domain::Crop::Dtos::ThermalRequirementOutputDto.new(requirement: requirement_mock)

    expected_json = {
      id: 123,
      crop_stage_id: 456,
      required_gdd: 1200.0
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :ok
    )

    presenter.on_success(success_dto)
  end

  test 'on_failure calls view.render_response with unprocessable_entity status and error message' do
    view_mock = mock
    presenter = Api::Crop::ThermalRequirementUpdatePresenter.new(view: view_mock)

    error_dto = Domain::Shared::Dtos::ErrorDto.new('Thermal requirement update failed')

    expected_json = {
      error: 'Thermal requirement update failed'
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :unprocessable_entity
    )

    presenter.on_failure(error_dto)
  end

  test 'on_failure handles non-ErrorDto failure objects' do
    view_mock = mock
    presenter = Api::Crop::ThermalRequirementUpdatePresenter.new(view: view_mock)

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