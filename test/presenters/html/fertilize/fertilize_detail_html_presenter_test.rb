# frozen_string_literal: true

require "test_helper"

class FertilizeDetailHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test "on_success sets @fertilize from dto entity" do
    view_mock = mock
    entity = mock
    dto = mock
    dto.expects(:fertilize).returns(entity)

    presenter = Presenters::Html::Fertilize::FertilizeDetailHtmlPresenter.new(view: view_mock)

    view_mock.expects(:instance_variable_set).with(:@fertilize, entity)

    presenter.on_success(dto)
  end

  test "on_failure redirects to fertilizes_path with alert" do
    view_mock = mock
    presenter = Presenters::Html::Fertilize::FertilizeDetailHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:respond_to?).with(:message).returns(true)
    error_dto.expects(:message).returns("Test error")

    view_mock.expects(:fertilizes_path).returns("/fertilizes")
    view_mock.expects(:redirect_to).with("/fertilizes", alert: "Test error")

    presenter.on_failure(error_dto)
  end

  test "on_failure uses flash and redirect for policy errors" do
    view_mock = mock
    presenter = Presenters::Html::Fertilize::FertilizeDetailHtmlPresenter.new(view: view_mock)

    error_dto = Domain::Shared::Policies::PolicyPermissionDenied.new

    flash_mock = mock
    flash_mock.expects(:[]=).with(:alert, I18n.t("fertilizes.flash.no_permission"))
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:fertilizes_path).returns("/fertilizes")
    view_mock.expects(:redirect_to).with("/fertilizes")

    presenter.on_failure(error_dto)
  end
end
