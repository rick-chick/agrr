# frozen_string_literal: true

require "test_helper"

class AgriculturalTaskDetailHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test "on_success sets @agricultural_task" do
    view_mock = mock
    detail_dto = mock

    presenter = Presenters::Html::AgriculturalTask::AgriculturalTaskDetailHtmlPresenter.new(view: view_mock)

    view_mock.expects(:instance_variable_set).with(:@agricultural_task, detail_dto)

    presenter.on_success(detail_dto)
  end

  test "on_failure sets flash alert and redirects" do
    view_mock = mock
    presenter = Presenters::Html::AgriculturalTask::AgriculturalTaskDetailHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:message).returns("Test error")

    flash_now_mock = mock
    flash_mock = mock
    flash_mock.expects(:now).returns(flash_now_mock)
    flash_now_mock.expects(:[]=).with(:alert, "Test error")
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:agricultural_tasks_path).returns("/agricultural_tasks")
    view_mock.expects(:redirect_to).with("/agricultural_tasks")

    presenter.on_failure(error_dto)
  end
end
