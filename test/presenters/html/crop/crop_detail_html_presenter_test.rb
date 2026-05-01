# frozen_string_literal: true

require "test_helper"

class CropDetailHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test "on_success sets @crop and show-related instance variables" do
    view_mock = mock
    crop_detail_dto = mock
    crop_model = mock
    blueprints = []
    tasks = []
    selected = [ 1, 2 ]

    crop_show_view_data_for = lambda { |dto|
      assert_equal crop_detail_dto, dto
      {
        crop: crop_model,
        task_schedule_blueprints: blueprints,
        available_agricultural_tasks: tasks,
        selected_task_ids: selected
      }
    }

    presenter = Presenters::Html::Crop::CropDetailHtmlPresenter.new(
      view: view_mock,
      crop_show_view_data_for: crop_show_view_data_for
    )

    view_mock.expects(:instance_variable_set).with(:@crop, crop_model)
    view_mock.expects(:instance_variable_set).with(:@task_schedule_blueprints, blueprints)
    view_mock.expects(:instance_variable_set).with(:@available_agricultural_tasks, tasks)
    view_mock.expects(:instance_variable_set).with(:@selected_task_ids, selected)

    presenter.on_success(crop_detail_dto)
  end

  test "on_failure sets flash alert and redirects" do
    view_mock = mock
    presenter = Presenters::Html::Crop::CropDetailHtmlPresenter.new(
      view: view_mock,
      crop_show_view_data_for: ->(_) { {} }
    )

    error_dto = mock
    error_dto.expects(:message).returns("Test error")

    flash_now_mock = mock
    flash_mock = mock
    flash_mock.expects(:now).returns(flash_now_mock)
    flash_now_mock.expects(:[]=).with(:alert, "Test error")
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:crops_path).returns("/crops")
    view_mock.expects(:redirect_to).with("/crops")

    presenter.on_failure(error_dto)
  end
end
