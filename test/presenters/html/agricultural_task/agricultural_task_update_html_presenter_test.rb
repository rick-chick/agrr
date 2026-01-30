# frozen_string_literal: true

require 'test_helper'

class AgriculturalTaskUpdateHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test 'on_success redirects with success notice' do
    view_mock = mock
    presenter = Presenters::Html::AgriculturalTask::AgriculturalTaskUpdateHtmlPresenter.new(view: view_mock)

    task_entity = mock

    view_mock.expects(:agricultural_task_path).with(task_entity).returns('/agricultural_tasks/1')
    view_mock.expects(:redirect_to).with('/agricultural_tasks/1', notice: I18n.t('agricultural_tasks.flash.updated'))

    presenter.on_success(task_entity)
  end

  test 'on_failure sets flash alert and renders edit template' do
    view_mock = mock
    presenter = Presenters::Html::AgriculturalTask::AgriculturalTaskUpdateHtmlPresenter.new(view: view_mock)

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