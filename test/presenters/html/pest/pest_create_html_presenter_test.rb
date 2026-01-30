# frozen_string_literal: true

require 'test_helper'

class PestCreateHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test 'on_success redirects with success notice' do
    view_mock = mock
    presenter = Presenters::Html::Pest::PestCreateHtmlPresenter.new(view: view_mock)

    pest_entity = mock
    pest_entity.expects(:id).returns(1)

    view_mock.expects(:pest_path).with(1).returns('/pests/1')
    view_mock.expects(:redirect_to).with('/pests/1', notice: I18n.t('pests.flash.created'))

    presenter.on_success(pest_entity)
  end

  test 'on_failure sets flash alert and renders new template' do
    view_mock = mock
    presenter = Presenters::Html::Pest::PestCreateHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:message).returns('Test error')

    flash_now_mock = mock
    flash_mock = mock
    flash_mock.expects(:now).returns(flash_now_mock)
    flash_now_mock.expects(:[]=).with(:alert, 'Test error')
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:render).with(:new, status: :unprocessable_entity)

    presenter.on_failure(error_dto)
  end
end