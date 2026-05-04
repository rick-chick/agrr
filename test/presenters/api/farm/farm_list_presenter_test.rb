# frozen_string_literal: true

require "test_helper"

class FarmListPresenterTest < ActiveSupport::TestCase
  FarmStub = Struct.new(:id, :name, :latitude, :longitude, :region, :user_id, :created_at, :updated_at, :is_reference,
    keyword_init: true)

  test "on_success renders farms array as root JSON with ok" do
    view_mock = mock
    presenter = Presenters::Api::Farm::FarmListPresenter.new(view: view_mock)

    t = Time.zone.parse("2024-01-15 12:00:00")
    farms = [
      FarmStub.new(
        id: 1,
        name: "A",
        latitude: 35.0,
        longitude: 139.0,
        region: "jp",
        user_id: 10,
        created_at: t,
        updated_at: t,
        is_reference: false
      ),
      FarmStub.new(
        id: 2,
        name: "B",
        latitude: 36.0,
        longitude: 140.0,
        region: "jp",
        user_id: 10,
        created_at: t,
        updated_at: t,
        is_reference: true
      )
    ]

    expected_json = [
      {
        id: 1,
        name: "A",
        latitude: 35.0,
        longitude: 139.0,
        region: "jp",
        user_id: 10,
        created_at: t,
        updated_at: t,
        is_reference: false
      },
      {
        id: 2,
        name: "B",
        latitude: 36.0,
        longitude: 140.0,
        region: "jp",
        user_id: 10,
        created_at: t,
        updated_at: t,
        is_reference: true
      }
    ]

    view_mock.expects(:render_response).with(json: expected_json, status: :ok)

    presenter.on_success(farms)
  end

  test "on_success ignores reference_farms keyword for response body" do
    view_mock = mock
    presenter = Presenters::Api::Farm::FarmListPresenter.new(view: view_mock)

    farms = []
    ref_extra = [ mock("ref") ]

    view_mock.expects(:render_response).with(json: [], status: :ok)

    presenter.on_success(farms, reference_farms: ref_extra)
  end

  test "on_success treats non-array farms as empty list" do
    view_mock = mock
    presenter = Presenters::Api::Farm::FarmListPresenter.new(view: view_mock)

    view_mock.expects(:render_response).with(json: [], status: :ok)

    presenter.on_success(nil)
  end

  test "on_failure renders forbidden for PolicyPermissionDenied" do
    view_mock = mock
    presenter = Presenters::Api::Farm::FarmListPresenter.new(view: view_mock)

    err = Domain::Shared::Policies::PolicyPermissionDenied.new

    view_mock.expects(:render_response).with(
      json: { error: I18n.t("farms.flash.no_permission") },
      status: :forbidden
    )

    presenter.on_failure(err)
  end

  test "on_failure renders unprocessable_entity with ErrorDto message" do
    view_mock = mock
    presenter = Presenters::Api::Farm::FarmListPresenter.new(view: view_mock)

    error_dto = Domain::Shared::Dtos::ErrorDto.new("Database connection failed")

    view_mock.expects(:render_response).with(
      json: { error: "Database connection failed" },
      status: :unprocessable_entity
    )

    presenter.on_failure(error_dto)
  end

  test "on_failure renders unprocessable_entity for string failure using to_s" do
    view_mock = mock
    presenter = Presenters::Api::Farm::FarmListPresenter.new(view: view_mock)

    view_mock.expects(:render_response).with(
      json: { error: "Some error string" },
      status: :unprocessable_entity
    )

    presenter.on_failure("Some error string")
  end
end
