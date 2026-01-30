# frozen_string_literal: true

require 'test_helper'

class FarmUpdateHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers
  test 'on_success redirects with success notice' do
    view_mock = mock
    presenter = Presenters::Html::Farm::FarmUpdateHtmlPresenter.new(view: view_mock)

    farm_entity = mock
    farm_model = mock('farm_model')
    farm_entity.expects(:to_model).returns(farm_model)

    view_mock.expects(:farm_path).with(farm_model).returns('/farms/1')
    view_mock.expects(:redirect_to).with('/farms/1', notice: I18n.t('farms.flash.updated'))

    presenter.on_success(farm_entity)
  end

  test 'on_failure sets flash alert and renders edit template' do
    view_mock = mock
    presenter = Presenters::Html::Farm::FarmUpdateHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:message).returns('Test error')

    flash_now_mock = mock
    flash_mock = mock
    flash_mock.expects(:now).returns(flash_now_mock)
    flash_now_mock.expects(:[]=).with(:alert, 'Test error')
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:render).with(:edit, status: :unprocessable_entity)

    presenter.on_failure(error_dto)
  end
end