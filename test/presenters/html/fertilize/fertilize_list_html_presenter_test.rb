# frozen_string_literal: true

require 'test_helper'

class FertilizeListHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test 'on_success sets @fertilizes' do
    view_mock = mock
    presenter = Presenters::Html::Fertilize::FertilizeListHtmlPresenter.new(view: view_mock)

    fertilize_entity1 = mock
    fertilize_entity2 = mock
    fertilize_model1 = mock
    fertilize_model2 = mock
    fertilize_entity1.expects(:to_model).returns(fertilize_model1)
    fertilize_entity2.expects(:to_model).returns(fertilize_model2)

    view_mock.expects(:instance_variable_set).with(:@fertilizes, [fertilize_model1, fertilize_model2])

    presenter.on_success([fertilize_entity1, fertilize_entity2])
  end

  test 'on_failure sets flash alert and renders index template' do
    view_mock = mock
    presenter = Presenters::Html::Fertilize::FertilizeListHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:respond_to?).with(:message).returns(true)
    error_dto.expects(:message).returns('Test error')

    flash_now_mock = mock
    flash_mock = mock
    flash_mock.expects(:now).returns(flash_now_mock)
    flash_now_mock.expects(:[]=).with(:alert, 'Test error')
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:render).with(:index, status: :unprocessable_entity)

    presenter.on_failure(error_dto)
  end
end