# frozen_string_literal: true

require 'test_helper'

class CropDetailHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers
  test 'on_success sets @crop and show-related instance variables' do
    view_mock = mock
    presenter = Presenters::Html::Crop::CropDetailHtmlPresenter.new(view: view_mock)

    crop_entity = mock
    crop_model = mock
    crop_entity.expects(:to_model).returns(crop_model)

    blueprints_relation = mock
    blueprints_relation.expects(:includes).with(:agricultural_task).returns(blueprints_relation)
    blueprints_relation.expects(:ordered).returns([])
    crop_model.expects(:crop_task_schedule_blueprints).returns(blueprints_relation)

    crop_model.expects(:crop_task_templates).returns(mock(pluck: mock(compact: mock(uniq: []))))

    crop_detail_dto = mock
    crop_detail_dto.expects(:crop).returns(crop_entity)

    view_mock.expects(:instance_variable_set).with(:@crop, crop_model)
    view_mock.expects(:instance_variable_set).with(:@task_schedule_blueprints, [])
    view_mock.expects(:instance_variable_set).with(:@available_agricultural_tasks, anything)
    view_mock.expects(:instance_variable_set).with(:@selected_task_ids, [])

    presenter.stubs(:available_agricultural_tasks_for_crop).returns([])
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