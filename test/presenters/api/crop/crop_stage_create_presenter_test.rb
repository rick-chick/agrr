# frozen_string_literal: true

require 'test_helper'

# Load the presenter class
require_relative '../../../../app/presenters/api/crop/crop_stage_create_presenter'

class CropStageCreatePresenterTest < ActiveSupport::TestCase
  test 'on_success calls view.render_response with created status and serialized success data' do
    view_mock = mock
    presenter = Api::Crop::CropStageCreatePresenter.new(view: view_mock)

    stage_mock = mock
    stage_mock.expects(:id).returns(123)
    stage_mock.expects(:crop_id).returns(456)
    stage_mock.expects(:name).returns('Flowering Stage')
    stage_mock.expects(:order).returns(2)

    success_dto = Domain::Crop::Dtos::CropStageOutputDto.new(stage: stage_mock)

    expected_json = {
      id: 123,
      crop_id: 456,
      name: 'Flowering Stage',
      order: 2
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :created
    )

    presenter.on_success(success_dto)
  end

  test 'on_failure calls view.render_response with unprocessable_entity status and error message' do
    view_mock = mock
    presenter = Api::Crop::CropStageCreatePresenter.new(view: view_mock)

    error_dto = Domain::Shared::Dtos::ErrorDto.new('Crop stage creation failed')

    expected_json = {
      error: 'Crop stage creation failed'
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :unprocessable_entity
    )

    presenter.on_failure(error_dto)
  end

  test 'on_failure handles non-ErrorDto failure objects' do
    view_mock = mock
    presenter = Api::Crop::CropStageCreatePresenter.new(view: view_mock)

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