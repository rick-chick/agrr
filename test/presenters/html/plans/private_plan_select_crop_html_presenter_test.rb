# frozen_string_literal: true

require "test_helper"

class PrivatePlanSelectCropHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test "on_success sets ivars from dto" do
    view_mock = mock
    farm = mock
    crops = [ mock ]
    dto = mock
    dto.expects(:farm).returns(farm)
    dto.expects(:plan_name).returns("P1")
    dto.expects(:crops).returns(crops)
    dto.expects(:total_area).returns(42.5)

    view_mock.expects(:instance_variable_set).with(:@farm, farm)
    view_mock.expects(:instance_variable_set).with(:@plan_name, "P1")
    view_mock.expects(:instance_variable_set).with(:@crops, crops)
    view_mock.expects(:instance_variable_set).with(:@total_area, 42.5)

    presenter = Presenters::Html::Plans::PrivatePlanSelectCropHtmlPresenter.new(view: view_mock)
    presenter.on_success(dto)
  end

  test "on_failure redirects to new_plan_path with alert" do
    view_mock = mock
    presenter = Presenters::Html::Plans::PrivatePlanSelectCropHtmlPresenter.new(view: view_mock)
    err = mock
    err.expects(:respond_to?).with(:message).returns(true)
    err.expects(:message).returns("bad")
    view_mock.expects(:new_plan_path).returns("/plans/new")
    view_mock.expects(:redirect_to).with("/plans/new", alert: "bad")
    presenter.on_failure(err)
  end
end
