# frozen_string_literal: true

require 'test_helper'

# Load the presenter class
require_relative '../../../../lib/presenters/api/crop/crop_stage_list_presenter'

class CropStageListPresenterTest < ActiveSupport::TestCase
  test 'on_success calls view.render_response with ok status and serialized success data' do
    view_mock = mock
    presenter = Presenters::Api::Crop::CropStageListPresenter.new(view: view_mock)

    stage_mock = mock
    stage_mock.expects(:id).returns(1)
    stage_mock.expects(:crop_id).returns(1)
    stage_mock.expects(:name).returns('種まき')
    stage_mock.expects(:order).returns(1)
    stage_mock.expects(:created_at).returns('2026-01-31T00:00:00.000Z')
    stage_mock.expects(:updated_at).returns('2026-01-31T00:00:00.000Z')

    success_dto = Domain::Crop::Dtos::CropStageListOutputDto.new(stages: [stage_mock])

    expected_json = [
      {
        id: 1,
        crop_id: 1,
        name: '種まき',
        order: 1,
        created_at: '2026-01-31T00:00:00.000Z',
        updated_at: '2026-01-31T00:00:00.000Z'
      }
    ]

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :ok
    )

    presenter.on_success(success_dto)
  end

  test 'on_success handles empty stages array' do
    view_mock = mock
    presenter = Presenters::Api::Crop::CropStageListPresenter.new(view: view_mock)

    success_dto = Domain::Crop::Dtos::CropStageListOutputDto.new(stages: [])

    expected_json = []

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :ok
    )

    presenter.on_success(success_dto)
  end

  test 'on_failure calls view.render_response with not_found status and error message' do
    view_mock = mock
    presenter = Presenters::Api::Crop::CropStageListPresenter.new(view: view_mock)

    error_dto = Domain::Shared::Dtos::ErrorDto.new('Crop not found')

    expected_json = {
      error: 'Crop not found'
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :not_found
    )

    presenter.on_failure(error_dto)
  end

  test 'on_failure handles non-ErrorDto failure objects' do
    view_mock = mock
    presenter = Presenters::Api::Crop::CropStageListPresenter.new(view: view_mock)

    failure_dto = 'Some error string'

    expected_json = {
      error: 'Some error string'
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :not_found
    )

    presenter.on_failure(failure_dto)
  end
end