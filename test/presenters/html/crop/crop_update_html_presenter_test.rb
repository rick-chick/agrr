# frozen_string_literal: true

require 'test_helper'

class CropUpdateHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers
  test 'on_success redirects with success notice' do
    view_mock = mock
    presenter = Presenters::Html::Crop::CropUpdateHtmlPresenter.new(view: view_mock)

    crop_entity = mock
    crop_model = mock('crop_model')
    crop_entity.expects(:id).returns(1)
    crop_entity.expects(:to_model).returns(crop_model)

    view_mock.expects(:crop_path).with(1).returns('/crops/1')
    view_mock.expects(:redirect_to).with('/crops/1', notice: I18n.t('crops.flash.updated'))

    presenter.on_success(crop_entity)
  end

  test 'on_failure sets flash alert and renders edit template' do
    view_mock = mock
    presenter = Presenters::Html::Crop::CropUpdateHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:message).returns('Test error')

    flash_now_mock = mock
    flash_mock = mock
    flash_mock.expects(:now).returns(flash_now_mock)
    flash_now_mock.expects(:[]=).with(:alert, 'Test error')
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:render_form).with(:edit, status: :unprocessable_entity)

    presenter.on_failure(error_dto)
  end
end