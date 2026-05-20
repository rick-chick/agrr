# frozen_string_literal: true

require "test_helper"

class CropStageCreatePresenterTest < ActiveSupport::TestCase
  test "on_success calls view.render_response with created status and serialized success data" do
    view_mock = mock
    presenter = Adapters::Crop::Presenters::Api::CropStageCreatePresenter.new(view: view_mock)

    stage_mock = mock
    stage_mock.expects(:id).returns(123)
    stage_mock.expects(:crop_id).returns(456)
    stage_mock.expects(:name).returns("Flowering Stage")
    stage_mock.expects(:order).returns(2)
    stage_mock.expects(:created_at).returns(Time.zone.parse("2025-01-01 12:00:00"))
    stage_mock.expects(:updated_at).returns(Time.zone.parse("2025-01-01 12:00:00"))

    success_dto = Domain::Crop::Dtos::CropStageOutput.new(stage: stage_mock)

    expected_json = {
      id: 123,
      crop_id: 456,
      name: "Flowering Stage",
      order: 2,
      created_at: Time.zone.parse("2025-01-01 12:00:00"),
      updated_at: Time.zone.parse("2025-01-01 12:00:00")
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :created
    )

    presenter.on_success(success_dto)
  end

  test "on_failure calls view.render_response with unprocessable_entity status and errors array" do
    view_mock = mock
    presenter = Adapters::Crop::Presenters::Api::CropStageCreatePresenter.new(view: view_mock)

    error_dto = Domain::Shared::Dtos::Error.new("Crop stage creation failed")

    expected_json = {
      errors: [ "Crop stage creation failed" ]
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :unprocessable_entity
    )

    presenter.on_failure(error_dto)
  end

  test "on_failure handles non-Error failure objects" do
    view_mock = mock
    presenter = Adapters::Crop::Presenters::Api::CropStageCreatePresenter.new(view: view_mock)

    failure_dto = "Some error string"

    expected_json = {
      errors: [ "Some error string" ]
    }

    view_mock.expects(:render_response).with(
      json: expected_json,
      status: :unprocessable_entity
    )

    presenter.on_failure(failure_dto)
  end
end
