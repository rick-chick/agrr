# frozen_string_literal: true

require "test_helper"

class AgriculturalTaskListHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test "on_success sets @agricultural_tasks and @reference_farms" do
    view_mock = mock
    presenter = Presenters::Html::AgriculturalTask::AgriculturalTaskListHtmlPresenter.new(view: view_mock)

    task_entity1 = mock
    task_entity2 = mock
    ref_entity = mock

    view_mock.expects(:instance_variable_set).with(:@agricultural_tasks, [ task_entity1, task_entity2 ])
    view_mock.expects(:instance_variable_set).with(:@query, "")
    view_mock.expects(:instance_variable_set).with(:@selected_filter, "user")
    view_mock.expects(:instance_variable_set).with(:@reference_farms, [ ref_entity ])

    presenter.on_success([ task_entity1, task_entity2 ], reference_tasks_for_index: [ ref_entity ])
  end

  test "on_failure sets flash alert and empty array" do
    view_mock = mock
    presenter = Presenters::Html::AgriculturalTask::AgriculturalTaskListHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:message).returns("Test error")

    flash_now_mock = mock
    flash_mock = mock
    flash_mock.expects(:now).returns(flash_now_mock)
    flash_now_mock.expects(:[]=).with(:alert, "Test error")
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:instance_variable_set).with(:@agricultural_tasks, [])
    view_mock.expects(:instance_variable_set).with(:@reference_farms, [])

    presenter.on_failure(error_dto)
  end

  test "on_failure redirects back with no_permission for policy errors" do
    view_mock = mock
    presenter = Presenters::Html::AgriculturalTask::AgriculturalTaskListHtmlPresenter.new(view: view_mock)

    error_dto = Domain::Shared::Policies::PolicyPermissionDenied.new

    view_mock.expects(:agricultural_tasks_path).returns("/agricultural_tasks")
    view_mock.expects(:redirect_back).with(
      fallback_location: "/agricultural_tasks",
      alert: I18n.t("agricultural_tasks.flash.no_permission")
    )

    presenter.on_failure(error_dto)
  end
end
