# frozen_string_literal: true

require "test_helper"

class FarmDetailHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test "on_success sets @farm and @fields" do
    view_mock = mock
    farm_record = mock
    fields = [ mock, mock ]
    farm_detail_dto = mock
    farm_detail_dto.expects(:farm).returns(farm_record)
    farm_detail_dto.expects(:fields).returns(fields)

    presenter = Presenters::Html::Farm::FarmDetailHtmlPresenter.new(view: view_mock)

    view_mock.expects(:instance_variable_set).with(:@farm, farm_record)
    view_mock.expects(:instance_variable_set).with(:@fields, fields)

    presenter.on_success(farm_detail_dto)
  end

  test "on_failure sets flash alert and redirects" do
    view_mock = mock
    presenter = Presenters::Html::Farm::FarmDetailHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:message).returns("Test error")

    flash_now_mock = mock
    flash_mock = mock
    flash_mock.expects(:now).returns(flash_now_mock)
    flash_now_mock.expects(:[]=).with(:alert, "Test error")
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:farms_path).returns("/farms")
    view_mock.expects(:redirect_to).with("/farms")

    presenter.on_failure(error_dto)
  end

  test "on_failure redirects with no_permission flash for policy errors" do
    view_mock = mock
    presenter = Presenters::Html::Farm::FarmDetailHtmlPresenter.new(view: view_mock)

    error_dto = Domain::Shared::Policies::PolicyPermissionDenied.new

    flash_mock = mock
    flash_mock.expects(:[]=).with(:alert, I18n.t("farms.flash.no_permission"))
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:farms_path).returns("/farms")
    view_mock.expects(:redirect_to).with("/farms")

    presenter.on_failure(error_dto)
  end
end
