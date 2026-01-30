# frozen_string_literal: true

require 'test_helper'

class PesticideDetailHtmlPresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test 'on_success sets @pesticide' do
    view_mock = mock
    presenter = Presenters::Html::Pesticide::PesticideDetailHtmlPresenter.new(view: view_mock)

    pesticide_entity = mock
    pesticide_model = mock
    pesticide_entity.expects(:to_model).returns(pesticide_model)

    pesticide_detail_dto = mock
    pesticide_detail_dto.expects(:pesticide).returns(pesticide_entity)

    view_mock.expects(:instance_variable_set).with(:@pesticide, pesticide_model)

    presenter.on_success(pesticide_detail_dto)
  end

  test 'on_failure sets flash alert and redirects' do
    view_mock = mock
    presenter = Presenters::Html::Pesticide::PesticideDetailHtmlPresenter.new(view: view_mock)

    error_dto = mock
    error_dto.expects(:message).returns('Test error')

    flash_now_mock = mock
    flash_mock = mock
    flash_mock.expects(:now).returns(flash_now_mock)
    flash_now_mock.expects(:[]=).with(:alert, 'Test error')
    view_mock.expects(:flash).returns(flash_mock)
    view_mock.expects(:pesticides_path).returns('/pesticides')
    view_mock.expects(:redirect_to).with('/pesticides')

    presenter.on_failure(error_dto)
  end
end