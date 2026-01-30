# frozen_string_literal: true

require 'test_helper'

class FarmDetailHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers
  test 'on_success sets @farm and @fields' do
    view_mock = mock
    presenter = Presenters::Html::Farm::FarmDetailHtmlPresenter.new(view: view_mock)

    farm_entity = mock
    farm_model = mock
    farm_entity.expects(:to_model).returns(farm_model)

    field_entity1 = mock
    field_entity2 = mock
    field_model1 = mock
    field_model2 = mock
    field_entity1.expects(:to_model).returns(field_model1)
    field_entity2.expects(:to_model).returns(field_model2)

    farm_detail_dto = mock
    farm_detail_dto.expects(:farm).returns(farm_entity)
    farm_detail_dto.expects(:fields).returns([field_entity1, field_entity2])

    view_mock.expects(:instance_variable_set).with(:@farm, farm_model)
    view_mock.expects(:instance_variable_set).with(:@fields, [field_model1, field_model2])

    presenter.on_success(farm_detail_dto)
  end

  test 'on_failure sets flash alert and redirects' do
    view_mock = mock
    presenter = Presenters::Html::Farm::FarmDetailHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:message).returns('Test error')

    flash_now_mock = mock
    flash_mock = mock
    flash_mock.expects(:now).returns(flash_now_mock)
    flash_now_mock.expects(:[]=).with(:alert, 'Test error')
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:farms_path).returns('/farms')
    view_mock.expects(:redirect_to).with('/farms')

    presenter.on_failure(error_dto)
  end
end