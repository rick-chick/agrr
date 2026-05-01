# frozen_string_literal: true

require "test_helper"

class FarmListHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  def build_row(id:)
    Domain::Farm::Dtos::FarmListRowDto.new(
      id: id,
      display_name: "F#{id}",
      latitude: 35.0,
      longitude: 135.0,
      region: "jp",
      user_id: 1,
      is_reference: false,
      field_count: 0,
      weather_data_status: "pending",
      weather_data_progress: 0,
      weather_data_total_years: 0,
      weather_data_status_text: "—",
      weather_data_last_error: nil
    )
  end

  test "on_success sets @farms and @reference_farms from rows bundle DTO" do
    view_mock = mock
    row1 = build_row(id: 1)
    ref_row = build_row(id: 99)
    success = Domain::Farm::Dtos::FarmListRowsBundleDto.new(
      farm_rows: [ row1 ],
      reference_farm_rows: [ ref_row ]
    )

    presenter = Presenters::Html::Farm::FarmListHtmlPresenter.new(view: view_mock)

    view_mock.expects(:instance_variable_set).with(:@farms, [ row1 ])
    view_mock.expects(:instance_variable_set).with(:@reference_farms, [ ref_row ])

    presenter.on_success(success)
  end

  test "on_failure sets flash alert and empty arrays" do
    view_mock = mock
    presenter = Presenters::Html::Farm::FarmListHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:message).returns("Test error")

    flash_now_mock = mock
    flash_mock = mock
    flash_mock.expects(:now).returns(flash_now_mock)
    flash_now_mock.expects(:[]=).with(:alert, "Test error")
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:instance_variable_set).with(:@farms, [])
    view_mock.expects(:instance_variable_set).with(:@reference_farms, [])

    presenter.on_failure(error_dto)
  end
end
