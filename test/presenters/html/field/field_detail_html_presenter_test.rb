# frozen_string_literal: true

require "test_helper"

class FieldDetailHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test "on_success sets @field" do
    view_mock = mock
    farm = mock
    field_model = mock
    detail_dto = mock

    field_record_for_detail_dto = lambda { |dto|
      assert_equal detail_dto, dto
      field_model
    }

    presenter = Presenters::Html::Field::FieldDetailHtmlPresenter.new(
      view: view_mock,
      farm: farm,
      field_record_for_detail_dto: field_record_for_detail_dto
    )

    view_mock.expects(:instance_variable_set).with(:@field, field_model)
    view_mock.expects(:instance_variable_set).with(:@farm, farm)

    presenter.on_success(detail_dto)
  end

  test "on_failure sets flash alert and redirects" do
    view_mock = mock
    farm = mock
    farm.expects(:id).returns(1)
    presenter = Presenters::Html::Field::FieldDetailHtmlPresenter.new(
      view: view_mock,
      farm: farm,
      field_record_for_detail_dto: ->(_) { nil }
    )

    error_dto = mock
    error_dto.expects(:message).returns("Test error")

    view_mock.expects(:farm_fields_path).with(1).returns("/farms/1/fields")
    view_mock.expects(:redirect_to).with("/farms/1/fields", alert: "Test error")

    presenter.on_failure(error_dto)
  end
end
