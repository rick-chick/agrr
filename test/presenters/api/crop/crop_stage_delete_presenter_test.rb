# frozen_string_literal: true

require 'test_helper'

# Load the presenter class
require_relative '../../../../lib/presenters/api/crop/crop_stage_delete_presenter'

class CropStageDeletePresenterTest < ActiveSupport::TestCase
  test 'on_success calls view.render_response with ok status and success json' do
    view_mock = mock
    presenter = Presenters::Api::Crop::CropStageDeletePresenter.new(view: view_mock)

    success_dto = Domain::Crop::Dtos::CropStageDeleteOutputDto.new(success: true)

    expected_json = { success: true }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :ok
    )

    presenter.on_success(success_dto)
  end

  test 'on_failure calls view.render_response with unprocessable_entity status and error message' do
    view_mock = mock
    presenter = Presenters::Api::Crop::CropStageDeletePresenter.new(view: view_mock)

    error_dto = Domain::Shared::Dtos::ErrorDto.new('Crop stage deletion failed')

    expected_json = {
      error: 'Crop stage deletion failed'
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :unprocessable_entity
    )

    presenter.on_failure(error_dto)
  end

  test 'on_failure handles non-ErrorDto failure objects' do
    view_mock = mock
    presenter = Presenters::Api::Crop::CropStageDeletePresenter.new(view: view_mock)

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