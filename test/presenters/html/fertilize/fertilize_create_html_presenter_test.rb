# frozen_string_literal: true

require 'test_helper'

class FertilizeCreateHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test 'on_success redirects with success notice' do
    view_mock = mock
    presenter = Presenters::Html::Fertilize::FertilizeCreateHtmlPresenter.new(view: view_mock)

    fertilize_entity = mock
    fertilize_entity.expects(:id).returns(1)

    view_mock.expects(:fertilize_path).with(1).returns('/fertilizes/1')
    view_mock.expects(:redirect_to).with('/fertilizes/1', notice: I18n.t('fertilizes.flash.created'))

    presenter.on_success(fertilize_entity)
  end

  test 'on_failure sets flash alert and renders new template' do
    view_mock = mock
    presenter = Presenters::Html::Fertilize::FertilizeCreateHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:respond_to?).with(:message).returns(true)
    error_dto.expects(:message).returns('Test error')

    view_mock.stubs(:params).returns(fertilize: {})
    flash_now_mock = mock
    flash_mock = mock
    view_mock.expects(:flash).returns(flash_mock)
    flash_mock.expects(:now).returns(flash_now_mock)
    flash_now_mock.expects(:[]=).with(:alert, 'Test error')
    view_mock.expects(:render).with(:new, status: :unprocessable_entity)

    presenter.on_failure(error_dto)
  end
end