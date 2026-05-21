# frozen_string_literal: true

require "test_helper"

class FarmListRowsBundleApiPresenterTest < ActiveSupport::TestCase
  class FakeView
    attr_reader :json, :status

    def render_response(json:, status:)
      @json = json
      @status = status
    end
  end

  def build_row(id:, name:, is_reference: false, created_at: nil, updated_at: nil)
    Domain::Farm::Dtos::FarmListRow.new(
      id: id,
      display_name: name,
      latitude: 35.0,
      longitude: 139.0,
      region: "jp",
      user_id: 10,
      is_reference: is_reference,
      field_count: 0,
      weather_data_status: "pending",
      weather_data_progress: 0,
      weather_data_total_years: 0,
      weather_data_last_error: nil,
      created_at: created_at,
      updated_at: updated_at
    )
  end

  test "on_success renders farms and reference_farms from rows bundle with ok" do
    view = FakeView.new
    presenter = Adapters::Farm::Presenters::FarmListRowsBundleApiPresenter.new(view: view)

    t = Time.zone.parse("2024-01-15 12:00:00")
    row_main = build_row(id: 1, name: "A", created_at: t, updated_at: t)
    row_ref = build_row(id: 2, name: "Ref", is_reference: true, created_at: t, updated_at: t)
    bundle = Domain::Farm::Dtos::FarmListRowsBundle.new(
      farm_rows: [ row_main ],
      reference_farm_rows: [ row_ref ]
    )

    presenter.on_success(bundle)

    assert_equal :ok, view.status
    assert_equal 2, view.json.keys.size
    assert_equal [ :farms, :reference_farms ], view.json.keys.sort

    assert_equal 1, view.json[:farms].size
    assert_equal(
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
      view.json[:farms].first
    )

    assert_equal 1, view.json[:reference_farms].size
    assert_equal(
      {
        id: 2,
        name: "Ref",
        latitude: 35.0,
        longitude: 139.0,
        region: "jp",
        user_id: 10,
        created_at: t,
        updated_at: t,
        is_reference: true
      },
      view.json[:reference_farms].first
    )
  end

  test "on_success defaults missing rows to empty arrays" do
    view = FakeView.new
    presenter = Adapters::Farm::Presenters::FarmListRowsBundleApiPresenter.new(view: view)

    bundle = Domain::Farm::Dtos::FarmListRowsBundle.new(
      farm_rows: [],
      reference_farm_rows: []
    )

    presenter.on_success(bundle)

    assert_equal :ok, view.status
    assert_equal [], view.json[:reference_farms]
    assert_equal [], view.json[:farms]
  end

  test "on_success treats non-array farm_rows as empty farms" do
    view = FakeView.new
    presenter = Adapters::Farm::Presenters::FarmListRowsBundleApiPresenter.new(view: view)

    bundle = Domain::Farm::Dtos::FarmListRowsBundle.new(
      farm_rows: nil,
      reference_farm_rows: []
    )

    presenter.on_success(bundle)

    assert_equal :ok, view.status
    assert_equal [], view.json[:farms]
    assert_equal [], view.json[:reference_farms]
  end

  test "on_success treats non-array reference_farm_rows as empty" do
    view = FakeView.new
    presenter = Adapters::Farm::Presenters::FarmListRowsBundleApiPresenter.new(view: view)

    bundle = Domain::Farm::Dtos::FarmListRowsBundle.new(
      farm_rows: [],
      reference_farm_rows: nil
    )

    presenter.on_success(bundle)

    assert_equal :ok, view.status
    assert_equal [], view.json[:reference_farms]
  end

  test "on_failure renders forbidden for PolicyPermissionDenied" do
    view = FakeView.new
    presenter = Adapters::Farm::Presenters::FarmListRowsBundleApiPresenter.new(view: view)

    err = Domain::Shared::Policies::PolicyPermissionDenied.new

    presenter.on_failure(err)

    assert_equal :forbidden, view.status
    assert_equal({ error: I18n.t("farms.flash.no_permission") }, view.json)
  end

  test "on_failure renders unprocessable_entity with Error message" do
    view = FakeView.new
    presenter = Adapters::Farm::Presenters::FarmListRowsBundleApiPresenter.new(view: view)

    error_dto = Domain::Shared::Dtos::Error.new("Database connection failed")

    presenter.on_failure(error_dto)

    assert_equal :unprocessable_entity, view.status
    assert_equal({ error: "Database connection failed" }, view.json)
  end

  test "on_failure renders unprocessable_entity for string failure using to_s" do
    view = FakeView.new
    presenter = Adapters::Farm::Presenters::FarmListRowsBundleApiPresenter.new(view: view)

    presenter.on_failure("Some error string")

    assert_equal :unprocessable_entity, view.status
    assert_equal({ error: "Some error string" }, view.json)
  end
end
