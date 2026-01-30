# frozen_string_literal: true

require 'test_helper'

class CropListHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers
  test 'on_success sets @crops' do
    view_mock = mock
    presenter = Presenters::Html::Crop::CropListHtmlPresenter.new(view: view_mock)

    crop_entity1 = mock
    crop_entity2 = mock
    crop_model1 = mock
    crop_model2 = mock
    crop_entity1.expects(:to_model).returns(crop_model1)
    crop_entity2.expects(:to_model).returns(crop_model2)

    view_mock.expects(:instance_variable_set).with(:@crops, [crop_model1, crop_model2])

    crops = [crop_entity1, crop_entity2]
    presenter.on_success(crops)
  end

  test 'on_failure sets flash alert and empty @crops' do
    view_mock = mock
    presenter = Presenters::Html::Crop::CropListHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:message).returns('Test error')

    flash_now_mock = mock
    flash_mock = mock
    flash_mock.expects(:now).returns(flash_now_mock)
    flash_now_mock.expects(:[]=).with(:alert, 'Test error')
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:instance_variable_set).with(:@crops, [])

    presenter.on_failure(error_dto)
  end
end