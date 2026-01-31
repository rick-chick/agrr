# frozen_string_literal: true

require 'test_helper'

class FertilizeDetailHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test 'on_success sets @fertilize from dto' do
    view_mock = mock
    presenter = Presenters::Html::Fertilize::FertilizeDetailHtmlPresenter.new(view: view_mock)

    fertilize_model = mock
    fertilize_entity = mock
    fertilize_entity.expects(:to_model).returns(fertilize_model)
    fertilize_detail_dto = mock
    fertilize_detail_dto.expects(:fertilize).returns(fertilize_entity)

    view_mock.expects(:instance_variable_set).with(:@fertilize, fertilize_model)

    presenter.on_success(fertilize_detail_dto)
  end

  test 'on_failure sets flash alert and renders show template' do
    view_mock = mock
    presenter = Presenters::Html::Fertilize::FertilizeDetailHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:respond_to?).with(:message).returns(true)
    error_dto.expects(:message).returns('Test error')

    flash_now_mock = mock
    flash_mock = mock
    flash_mock.expects(:now).returns(flash_now_mock)
    flash_now_mock.expects(:[]=).with(:alert, 'Test error')
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:render).with(:show, status: :unprocessable_entity)

    presenter.on_failure(error_dto)
  end
end