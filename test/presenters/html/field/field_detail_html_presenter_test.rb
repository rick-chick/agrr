# frozen_string_literal: true

require "test_helper"

class FieldDetailHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test "on_success sets @farm and @field from FieldWithFarm" do
    view_mock = mock
    farm = mock
    field = mock
    result = Domain::Field::Results::FieldWithFarm.new(farm: farm, field: field)

    presenter = Presenters::Html::Field::FieldDetailHtmlPresenter.new(view: view_mock)

    view_mock.expects(:instance_variable_set).with(:@farm, farm)
    view_mock.expects(:instance_variable_set).with(:@field, field)

    presenter.on_success(result)
  end

  test "on_failure redirects to farm_fields_path when farm_id in params" do
    view_mock = mock
    view_mock.expects(:params).returns(ActionController::Parameters.new(farm_id: "7"))

    presenter = Presenters::Html::Field::FieldDetailHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:message).returns("Field not found")

    view_mock.expects(:farm_fields_path).with("7").returns("/farms/7/fields")
    view_mock.expects(:redirect_to).with("/farms/7/fields", alert: "Field not found")

    presenter.on_failure(error_dto)
  end

  test "on_failure redirects to farms_path when farm_id missing" do
    view_mock = mock
    view_mock.expects(:params).returns(ActionController::Parameters.new)

    presenter = Presenters::Html::Field::FieldDetailHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:message).returns("x")

    view_mock.expects(:farms_path).returns("/farms")
    view_mock.expects(:redirect_to).with("/farms", alert: "x")

    presenter.on_failure(error_dto)
  end
end
