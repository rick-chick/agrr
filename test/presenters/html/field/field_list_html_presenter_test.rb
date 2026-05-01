# frozen_string_literal: true

require "test_helper"

class FieldListHtmlPresenterTest < ActiveSupport::TestCase
  test "on_success sets @farm and @fields from FarmFieldsList" do
    view_mock = mock
    farm = mock
    field_entity = mock
    result = Domain::Field::Results::FarmFieldsList.new(farm: farm, fields: [ field_entity ])

    presenter = Presenters::Html::Field::FieldListHtmlPresenter.new(view: view_mock)

    view_mock.expects(:instance_variable_set).with(:@farm, farm)
    view_mock.expects(:instance_variable_set).with(:@fields, [ field_entity ])

    presenter.on_success(result)
  end

  test "on_failure redirects to farms_path with alert" do
    view_mock = mock
    presenter = Presenters::Html::Field::FieldListHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:message).returns("Farm not found")

    view_mock.expects(:farms_path).returns("/farms")
    view_mock.expects(:redirect_to).with("/farms", alert: "Farm not found")

    presenter.on_failure(error_dto)
  end
end
