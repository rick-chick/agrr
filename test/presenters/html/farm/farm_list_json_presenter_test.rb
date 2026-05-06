# frozen_string_literal: true

require "test_helper"

class FarmListJsonPresenterTest < ActiveSupport::TestCase
  FarmStub = Struct.new(:id, :name, :latitude, :longitude, :region, :user_id, :created_at, :updated_at, :is_reference,
    keyword_init: true)

  class FakeView
    attr_reader :json, :status

    def render_response(json:, status:)
      @json = json
      @status = status
    end
  end

  test "on_success renders farms and reference_farms with ok" do
    view = FakeView.new
    presenter = Presenters::Html::Farm::FarmListJsonPresenter.new(view: view)

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
      )
    ]
    reference_farms = [
      FarmStub.new(
        id: 2,
        name: "Ref",
        latitude: 36.0,
        longitude: 140.0,
        region: "jp",
        user_id: 11,
        created_at: t,
        updated_at: t,
        is_reference: true
      )
    ]

    presenter.on_success(farms, reference_farms: reference_farms)

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
        latitude: 36.0,
        longitude: 140.0,
        region: "jp",
        user_id: 11,
        created_at: t,
        updated_at: t,
        is_reference: true
      },
      view.json[:reference_farms].first
    )
  end

  test "on_success defaults reference_farms to empty when keyword omitted" do
    view = FakeView.new
    presenter = Presenters::Html::Farm::FarmListJsonPresenter.new(view: view)

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
      )
    ]

    presenter.on_success(farms)

    assert_equal :ok, view.status
    assert_equal [], view.json[:reference_farms]
    assert_equal 1, view.json[:farms].size
  end

  test "on_success treats non-array farms as empty farms" do
    view = FakeView.new
    presenter = Presenters::Html::Farm::FarmListJsonPresenter.new(view: view)

    presenter.on_success(nil, reference_farms: [])

    assert_equal :ok, view.status
    assert_equal [], view.json[:farms]
    assert_equal [], view.json[:reference_farms]
  end

  test "on_success treats non-array reference_farms as empty" do
    view = FakeView.new
    presenter = Presenters::Html::Farm::FarmListJsonPresenter.new(view: view)

    presenter.on_success([], reference_farms: nil)

    assert_equal :ok, view.status
    assert_equal [], view.json[:reference_farms]
  end

  test "on_failure renders forbidden for PolicyPermissionDenied" do
    view = FakeView.new
    presenter = Presenters::Html::Farm::FarmListJsonPresenter.new(view: view)

    err = Domain::Shared::Policies::PolicyPermissionDenied.new

    presenter.on_failure(err)

    assert_equal :forbidden, view.status
    assert_equal({ error: I18n.t("farms.flash.no_permission") }, view.json)
  end

  test "on_failure renders unprocessable_entity with ErrorDto message" do
    view = FakeView.new
    presenter = Presenters::Html::Farm::FarmListJsonPresenter.new(view: view)

    error_dto = Domain::Shared::Dtos::ErrorDto.new("Database connection failed")

    presenter.on_failure(error_dto)

    assert_equal :unprocessable_entity, view.status
    assert_equal({ error: "Database connection failed" }, view.json)
  end

  test "on_failure renders unprocessable_entity for string failure using to_s" do
    view = FakeView.new
    presenter = Presenters::Html::Farm::FarmListJsonPresenter.new(view: view)

    presenter.on_failure("Some error string")

    assert_equal :unprocessable_entity, view.status
    assert_equal({ error: "Some error string" }, view.json)
  end
end
