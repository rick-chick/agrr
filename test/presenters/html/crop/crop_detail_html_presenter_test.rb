# frozen_string_literal: true

require "test_helper"

class CropDetailHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test "on_success sets @crop from dto persisted_crop and related instance variables" do
    view_mock = Minitest::Mock.new
    crop_model = Object.new
    blueprints = []
    tasks = []
    selected = [ 1, 2 ]

    crop_detail_dto = Struct.new(
      :persisted_crop,
      :task_schedule_blueprints,
      :available_agricultural_tasks,
      :selected_task_ids
    ).new(crop_model, blueprints, tasks, selected)

    presenter = Presenters::Html::Crop::CropDetailHtmlPresenter.new(
      view: view_mock
    )

    view_mock.expect(:instance_variable_set, nil, [ :@crop, crop_model ])
    view_mock.expect(:instance_variable_set, nil, [ :@task_schedule_blueprints, blueprints ])
    view_mock.expect(:instance_variable_set, nil, [ :@available_agricultural_tasks, tasks ])
    view_mock.expect(:instance_variable_set, nil, [ :@selected_task_ids, selected ])

    presenter.on_success(crop_detail_dto)

    assert_nothing_raised { view_mock.verify }
  end

  test "on_failure redirects with no_permission flash for policy errors" do
    view_mock = Minitest::Mock.new
    presenter = Presenters::Html::Crop::CropDetailHtmlPresenter.new(
      view: view_mock
    )

    error_dto = Domain::Shared::Policies::PolicyPermissionDenied.new

    flash_mock = Minitest::Mock.new
    flash_mock.expect(:[]=, nil, [ :alert, I18n.t("crops.flash.no_permission") ])

    view_mock.expect(:flash, flash_mock)
    view_mock.expect(:crops_path, "/crops")
    view_mock.expect(:redirect_to, nil, [ "/crops" ])

    presenter.on_failure(error_dto)

    assert_nothing_raised do
      flash_mock.verify
      view_mock.verify
    end
  end
end
