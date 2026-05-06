# frozen_string_literal: true

require "test_helper"

class FertilizeUpdateHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test "on_success redirects with success notice" do
    view_mock = mock
    presenter = Presenters::Html::Fertilize::FertilizeUpdateHtmlPresenter.new(view: view_mock)

    fertilize_entity = mock
    fertilize_entity.expects(:id).returns(1)

    view_mock.expects(:fertilize_path).with(1).returns("/fertilizes/1")
    view_mock.expects(:redirect_to).with("/fertilizes/1", notice: I18n.t("fertilizes.flash.updated"))

    presenter.on_success(fertilize_entity)
  end

  test "on_failure sets flash alert and renders edit template" do
    view_mock = mock
    fertilize_mock = mock
    failure_dto = Domain::Fertilize::Dtos::FertilizeUpdateFailureDto.new(message: "Test error", form_fertilize: fertilize_mock)
    presenter = Presenters::Html::Fertilize::FertilizeUpdateHtmlPresenter.new(view: view_mock)

    fertilize_mock.expects(:assign_attributes)
    fertilize_mock.expects(:valid?)

    view_mock.stubs(:params).returns(id: 1, fertilize: {})
    view_mock.expects(:instance_variable_set).with(:@fertilize, fertilize_mock)
    flash_now_mock = mock
    flash_mock = mock
    view_mock.expects(:flash).returns(flash_mock)
    flash_mock.expects(:now).returns(flash_now_mock)
    flash_now_mock.expects(:[]=).with(:alert, "Test error")
    view_mock.expects(:render).with(:edit, status: :unprocessable_entity)

    presenter.on_failure(failure_dto)
  end

  test "on_failure redirects to index when form_fertilize missing" do
    view_mock = mock
    failure_dto = Domain::Fertilize::Dtos::FertilizeUpdateFailureDto.new(message: "Lost model", form_fertilize: nil)
    presenter = Presenters::Html::Fertilize::FertilizeUpdateHtmlPresenter.new(view: view_mock)

    flash_now_mock = mock
    flash_mock = mock
    view_mock.expects(:flash).returns(flash_mock)
    flash_mock.expects(:now).returns(flash_now_mock)
    flash_now_mock.expects(:[]=).with(:alert, "Lost model")
    view_mock.expects(:fertilizes_path).returns("/fertilizes")
    view_mock.expects(:redirect_to).with("/fertilizes")

    presenter.on_failure(failure_dto)
  end

  test "on_failure redirects back with no_permission for policy errors" do
    view_mock = mock
    presenter = Presenters::Html::Fertilize::FertilizeUpdateHtmlPresenter.new(view: view_mock)

    error_dto = Domain::Shared::Policies::PolicyPermissionDenied.new

    view_mock.expects(:fertilizes_path).returns("/fertilizes")
    view_mock.expects(:redirect_back).with(
      fallback_location: "/fertilizes",
      alert: I18n.t("fertilizes.flash.no_permission")
    )

    presenter.on_failure(error_dto)
  end

  test "on_failure redirects to edit when non-admin toggles reference flag" do
    view_mock = mock
    msg = I18n.t("fertilizes.flash.reference_flag_admin_only")
    fertilize_mock = mock
    failure_dto = Domain::Fertilize::Dtos::FertilizeUpdateFailureDto.new(message: msg, form_fertilize: fertilize_mock)
    presenter = Presenters::Html::Fertilize::FertilizeUpdateHtmlPresenter.new(view: view_mock)

    view_mock.stubs(:params).returns(id: "42", fertilize: {})
    view_mock.expects(:fertilize_path).with("42").returns("/fertilizes/42")
    view_mock.expects(:redirect_to).with("/fertilizes/42", alert: msg)

    presenter.on_failure(failure_dto)
  end
end
