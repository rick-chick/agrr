# frozen_string_literal: true

require 'test_helper'

class PesticideListHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test 'on_success sets @pesticides' do
    view_mock = mock
    presenter = Presenters::Html::Pesticide::PesticideListHtmlPresenter.new(view: view_mock)

    pesticide_entity1 = mock
    pesticide_entity2 = mock
    pesticide_model1 = mock
    pesticide_model2 = mock
    pesticide_entity1.expects(:to_model).returns(pesticide_model1)
    pesticide_entity2.expects(:to_model).returns(pesticide_model2)

    view_mock.expects(:instance_variable_set).with(:@pesticides, [pesticide_model1, pesticide_model2])

    pesticides = [pesticide_entity1, pesticide_entity2]
    presenter.on_success(pesticides)
  end

  test 'on_failure sets flash alert and empty @pesticides' do
    view_mock = mock
    presenter = Presenters::Html::Pesticide::PesticideListHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:message).returns('Test error')

    flash_now_mock = mock
    flash_mock = mock
    flash_mock.expects(:now).returns(flash_now_mock)
    flash_now_mock.expects(:[]=).with(:alert, 'Test error')
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:instance_variable_set).with(:@pesticides, [])

    presenter.on_failure(error_dto)
  end
end