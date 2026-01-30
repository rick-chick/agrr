# frozen_string_literal: true

require 'test_helper'

class CropDetailHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers
  test 'on_success sets @crop' do
    view_mock = mock
    presenter = Presenters::Html::Crop::CropDetailHtmlPresenter.new(view: view_mock)

    crop_entity = mock
    crop_model = mock
    crop_entity.expects(:to_model).returns(crop_model)

    crop_detail_dto = mock
    crop_detail_dto.expects(:crop).returns(crop_entity)

    view_mock.expects(:instance_variable_set).with(:@crop, crop_model)

    presenter.on_success(crop_detail_dto)
  end

  test 'on_failure sets flash alert and redirects' do
    view_mock = mock
    presenter = Presenters::Html::Crop::CropDetailHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:message).returns('Test error')

    flash_now_mock = mock
    flash_mock = mock
    flash_mock.expects(:now).returns(flash_now_mock)
    flash_now_mock.expects(:[]=).with(:alert, 'Test error')
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:crops_path).returns('/crops')
    view_mock.expects(:redirect_to).with('/crops')

    presenter.on_failure(error_dto)
  end
end