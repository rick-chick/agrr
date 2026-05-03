# frozen_string_literal: true

require "test_helper"

class PesticideListHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test "on_success sets @pesticides" do
    view_mock = mock
    pesticide_entity1 = mock
    pesticide_entity2 = mock

    presenter = Presenters::Html::Pesticide::PesticideListHtmlPresenter.new(view: view_mock)

    entities = [ pesticide_entity1, pesticide_entity2 ]
    view_mock.expects(:instance_variable_set).with(:@pesticides, entities)

    presenter.on_success(entities)
  end

  test "on_failure sets flash alert and empty @pesticides" do
    view_mock = mock
    presenter = Presenters::Html::Pesticide::PesticideListHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:message).returns("Test error")

    flash_now_mock = mock
    flash_mock = mock
    flash_mock.expects(:now).returns(flash_now_mock)
    flash_now_mock.expects(:[]=).with(:alert, "Test error")
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:instance_variable_set).with(:@pesticides, [])

    presenter.on_failure(error_dto)
  end

  test "on_failure redirects back with no_permission for policy errors" do
    view_mock = mock
    presenter = Presenters::Html::Pesticide::PesticideListHtmlPresenter.new(view: view_mock)

    error_dto = Domain::Shared::Policies::PolicyPermissionDenied.new

    view_mock.expects(:pesticides_path).returns("/pesticides")
    view_mock.expects(:redirect_back).with(
      fallback_location: "/pesticides",
      alert: I18n.t("pesticides.flash.no_permission")
    )

    presenter.on_failure(error_dto)
  end
end
