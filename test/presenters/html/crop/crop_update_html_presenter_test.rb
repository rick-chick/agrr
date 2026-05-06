# frozen_string_literal: true

require "test_helper"

class CropUpdateHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers
  test "on_success redirects with success notice" do
    view_mock = mock
    presenter = Presenters::Html::Crop::CropUpdateHtmlPresenter.new(view: view_mock)

    crop_entity = mock
    crop_entity.expects(:id).returns(1)

    view_mock.expects(:crop_path).with(1).returns("/crops/1")
    view_mock.expects(:redirect_to).with("/crops/1", notice: I18n.t("crops.flash.updated"))

    presenter.on_success(crop_entity)
  end

  test "on_failure sets flash alert and renders edit template" do
    view_mock = mock
    presenter = Presenters::Html::Crop::CropUpdateHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:message).returns("Test error")

    flash_now_mock = mock
    flash_mock = mock
    flash_mock.expects(:now).returns(flash_now_mock)
    flash_now_mock.expects(:[]=).with(:alert, "Test error")
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:after_crop_update_failure)
    view_mock.expects(:render_form).with(:edit, status: :unprocessable_entity)

    presenter.on_failure(error_dto)
  end

  test "on_failure redirects for policy permission denied" do
    view_mock = mock
    presenter = Presenters::Html::Crop::CropUpdateHtmlPresenter.new(view: view_mock)

    error_dto = Domain::Shared::Policies::PolicyPermissionDenied.new

    flash_mock = mock
    flash_mock.expects(:[]=).with(:alert, I18n.t("crops.flash.no_permission"))
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:crops_path).returns("/crops")
    view_mock.expects(:redirect_to).with("/crops")

    presenter.on_failure(error_dto)
  end

  test "on_failure redirects to show when non-admin toggles reference flag" do
    view_mock = mock
    presenter = Presenters::Html::Crop::CropUpdateHtmlPresenter.new(view: view_mock)

    msg = I18n.t("crops.flash.reference_flag_admin_only")
    error_dto = Domain::Shared::Dtos::ErrorDto.new(msg)

    view_mock.stubs(:params).returns(id: "9")
    view_mock.expects(:crop_path).with("9").returns("/crops/9")
    view_mock.expects(:redirect_to).with("/crops/9", alert: msg)

    presenter.on_failure(error_dto)
  end
end
