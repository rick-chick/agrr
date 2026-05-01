# frozen_string_literal: true

require "test_helper"

class PestUpdateHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test "on_success redirects with success notice" do
    view_mock = mock
    presenter = Presenters::Html::Pest::PestUpdateHtmlPresenter.new(view: view_mock)

    pest_entity = mock
    pest_entity.expects(:id).returns(1)

    view_mock.expects(:pest_path).with(1).returns("/pests/1")
    view_mock.expects(:redirect_to).with("/pests/1", notice: I18n.t("pests.flash.updated"))

    presenter.on_success(pest_entity)
  end

  test "on_failure sets flash alert and renders edit template" do
    view_mock = mock
    pest_mock = mock
    presenter = Presenters::Html::Pest::PestUpdateHtmlPresenter.new(view: view_mock)

    reload_bundle = mock
    reload_bundle.stubs(:persisted_pest).returns(pest_mock)
    failure_dto = Domain::Pest::Dtos::PestUpdateFailureDto.new(message: "Test error", reload_bundle: reload_bundle)

    pest_mock.expects(:assign_attributes)
    pest_params_mock = mock
    pest_params_mock.stubs(:permit).returns({})

    view_mock.stubs(:params).returns(id: 1, pest: pest_params_mock, crop_ids: nil)
    view_mock.stubs(:prepare_crop_selection_for)
    view_mock.stubs(:normalize_crop_ids_for)

    flash_now_mock = mock
    flash_mock = mock
    flash_mock.expects(:now).returns(flash_now_mock)
    flash_now_mock.expects(:[]=).with(:alert, "Test error")
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:instance_variable_set).with(:@pest, pest_mock)
    view_mock.expects(:render_form).with(:edit, status: :unprocessable_entity)

    presenter.on_failure(failure_dto)
  end
end
