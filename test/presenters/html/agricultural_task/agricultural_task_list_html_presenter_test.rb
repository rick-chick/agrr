# frozen_string_literal: true

require 'test_helper'

class AgriculturalTaskListHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test 'on_success sets @agricultural_tasks' do
    view_mock = mock
    presenter = Presenters::Html::AgriculturalTask::AgriculturalTaskListHtmlPresenter.new(view: view_mock)

    task_entity1 = mock
    task_entity2 = mock
    task_model1 = mock
    task_model2 = mock
    task_entity1.expects(:to_model).returns(task_model1)
    task_entity2.expects(:to_model).returns(task_model2)

    view_mock.expects(:instance_variable_set).with(:@agricultural_tasks, [task_model1, task_model2])

    tasks = [task_entity1, task_entity2]
    presenter.on_success(tasks)
  end

  test 'on_failure sets flash alert and empty array' do
    view_mock = mock
    presenter = Presenters::Html::AgriculturalTask::AgriculturalTaskListHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:message).returns('Test error')

    flash_now_mock = mock
    flash_mock = mock
    flash_mock.expects(:now).returns(flash_now_mock)
    flash_now_mock.expects(:[]=).with(:alert, 'Test error')
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:instance_variable_set).with(:@agricultural_tasks, [])

    presenter.on_failure(error_dto)
  end
end